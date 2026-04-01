#!/usr/bin/env wish

package require Tk 8.6

namespace eval wb {
    variable ui

    # --------------------------------------------------
    # Shared
    # --------------------------------------------------
    variable selectedPath ""
    variable previewImage ""
    variable currentRoot ""

    variable lastRunOutputDir ""
    variable lastRunLogFile ""

    # --------------------------------------------------
    # Experiments
    # --------------------------------------------------
    variable experiments {}
    variable experimentsFile "experiments_db.tcl"
    variable selectedExperimentIndex -1

    variable filterDomain "all"
    variable filterStatus "all"
    variable searchText ""

    variable expId ""
    variable expName ""
    variable expDomain "radar"
    variable expStatus "draft"
    variable expDescription ""
    variable expConfigPath ""
    variable expWorkflowPath ""
    variable expOutputDir ""
    variable expLogPath ""
    variable expBaselinePath ""
    variable expMetricsPath ""
    variable expTags ""
    variable expNotes ""
    variable expCreatedAt ""

    # --------------------------------------------------
    # Validation
    # --------------------------------------------------
    variable metricsFile ""
    variable baselineFile ""
    variable metricsData {}
    variable baselineData {}
    variable passCount 0
    variable warnCount 0
    variable failCount 0

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
            workdir "."
            extra_args "--mode batch"
        }
        {
            name "Satellite Matlab Visibility"
            domain "satellite"
            type "matlab_function"
            launcher "matlab"
            target "run_visibility_case"
            workdir "."
            extra_args ""
        }
        {
            name "Underwater C++ Detector"
            domain "underwater"
            type "cpp_executable"
            launcher ""
            target "./uw_detector"
            workdir "."
            extra_args "--threshold auto"
        }
        {
            name "HDL Regression Runner"
            domain "hdl"
            type "hdl_runner"
            launcher "python3"
            target "run_hdl_regression.py"
            workdir "."
            extra_args "--suite smoke --waves"
        }
    }

    variable launchProfile "Radar Python Chain"
    variable launchConfigPath ""
    variable launchCaseName ""
    variable launchInputData ""
    variable launchOutputRoot "./runs"
    variable launchWorkdir "."
    variable launchExtraArgs ""

    variable running 0
    variable processChan ""
    variable processPid ""
    variable runtimeLogChan ""

    # --------------------------------------------------
    # Workflow
    # --------------------------------------------------
    variable wfNodes
    array set wfNodes {}
    variable wfEdges {}
    variable wfNextNodeId 1
    variable wfSelectedNode ""
    variable wfMode "select"
    variable wfPendingNodeType "Process"
    variable wfConnectFrom ""
    variable wfDragNode ""
    variable wfDragLastX 0
    variable wfDragLastY 0
    variable wfNodeWidth 140
    variable wfNodeHeight 60
    variable wfWorkflowFile ""

    variable wfPropName ""
    variable wfPropType "Process"
    variable wfPropLauncherProfile ""
    variable wfPropConfigPath ""
    variable wfPropLogPath ""
    variable wfPropWorkDir "."
    variable wfPropExtraArgs ""
    variable wfPropNotes ""

    variable wfPropState ""
    variable wfPropLastMessage ""
    variable wfPropLastExitCode ""
    variable wfPropLastRunTs ""

    variable wfExecutionQueue {}
    variable wfRunningNode ""
    variable wfRunning 0
    variable wfProcessChan ""
    variable wfProcessPid ""

    # --------------------------------------------------
    # Log analyzer
    # --------------------------------------------------
    variable analyzerCurrentFile ""
    variable analyzerRawLines {}
    variable analyzerVisibleLines {}
    variable analyzerSearchText ""
    variable analyzerFilterError 1
    variable analyzerFilterWarn 1
    variable analyzerFilterInfo 1
    variable analyzerFilterDebug 1
    variable analyzerOnlyMatching 0
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
# EXPERIMENTS
# ==================================================
proc wb::defaultExperiments {} {
    return {
        {
            id EXP001
            name "Radar Batch Alpha"
            domain radar
            status completed
            description "Prima campagna radar batch"
            configPath "configs/radar_alpha.json"
            workflowPath "workflows/radar_alpha.wflow"
            outputDir "runs/radar_alpha"
            logPath "runs/radar_alpha/run.log"
            baselinePath "runs/radar_alpha/baseline.csv"
            metricsPath "runs/radar_alpha/metrics.csv"
            tags "radar,batch,alpha"
            notes "Run completata con warning minori"
            createdAt "2026-03-31 10:15:00"
        }
        {
            id EXP002
            name "Satellite Visibility LEO-A"
            domain satellite
            status ready
            description "Analisi finestre di visibilità per caso LEO"
            configPath "configs/leo_a.json"
            workflowPath "workflows/leo_visibility.wflow"
            outputDir "runs/leo_a"
            logPath ""
            baselinePath ""
            metricsPath ""
            tags "satellite,visibility,leo"
            notes "Pronta per batch Matlab"
            createdAt "2026-03-31 11:40:00"
        }
    }
}

proc wb::loadExperimentsDb {} {
    variable experimentsFile
    variable experiments

    if {[file exists $experimentsFile]} {
        if {[catch {
            set f [open $experimentsFile r]
            set experiments [read $f]
            close $f
        } err]} {
            set experiments [wb::defaultExperiments]
            wb::setStatus "errore caricamento db"
            return
        }
    } else {
        set experiments [wb::defaultExperiments]
    }
    wb::setStatus "database esperimenti caricato"
}

proc wb::saveExperimentsDb {} {
    variable experimentsFile
    variable experiments
    if {[catch {
        set f [open $experimentsFile w]
        puts $f $experiments
        close $f
    } err]} {
        tk_messageBox -icon error -title "Errore" -message "Salvataggio DB fallito:\n$err"
        return
    }
    wb::setStatus "database esperimenti salvato"
}

proc wb::nextExperimentId {} {
    variable experiments
    set maxNum 0
    foreach exp $experiments {
        if {[dict exists $exp id]} {
            set id [dict get $exp id]
            if {[regexp {^EXP([0-9]+)$} $id -> num]} {
                if {$num > $maxNum} { set maxNum $num }
            }
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
    set ::wb::expDescription ""
    set ::wb::expConfigPath ""
    set ::wb::expWorkflowPath ""
    set ::wb::expOutputDir ""
    set ::wb::expLogPath ""
    set ::wb::expBaselinePath ""
    set ::wb::expMetricsPath ""
    set ::wb::expTags ""
    set ::wb::expNotes ""
    set ::wb::expCreatedAt ""
    if {[winfo exists .experimentsTab.right.form.tnotes]} {
        .experimentsTab.right.form.tnotes delete 1.0 end
    }
}

proc wb::populateExperimentNotesWidget {} {
    if {[winfo exists .experimentsTab.right.form.tnotes]} {
        .experimentsTab.right.form.tnotes delete 1.0 end
        .experimentsTab.right.form.tnotes insert end $::wb::expNotes
    }
}

proc wb::readExperimentNotesWidget {} {
    if {[winfo exists .experimentsTab.right.form.tnotes]} {
        set ::wb::expNotes [string trim [.experimentsTab.right.form.tnotes get 1.0 end]]
    }
}

proc wb::experimentMatchesFilters {exp} {
    variable filterDomain
    variable filterStatus
    variable searchText

    if {$filterDomain ne "all" && [dict get $exp domain] ne $filterDomain} { return 0 }
    if {$filterStatus ne "all" && [dict get $exp status] ne $filterStatus} { return 0 }

    set needle [string trim [string tolower $searchText]]
    if {$needle ne ""} {
        set hay [string tolower "[dict get $exp id] [dict get $exp name] [dict get $exp tags] [dict get $exp description]"]
        if {[string first $needle $hay] < 0} { return 0 }
    }
    return 1
}

proc wb::refreshExperimentsTable {} {
    variable ui
    variable experiments

    set tree $ui(expTree)
    foreach item [$tree children {}] { $tree delete $item }

    set idx 0
    foreach exp $experiments {
        if {![wb::experimentMatchesFilters $exp]} {
            incr idx
            continue
        }
        $tree insert {} end -id "row$idx" -values [list \
            $idx \
            [dict get $exp id] \
            [dict get $exp name] \
            [dict get $exp domain] \
            [dict get $exp status] \
            [dict get $exp createdAt]]
        incr idx
    }
    wb::setStatus "tabella esperimenti aggiornata"
}

proc wb::loadExperimentIntoEditor {index} {
    variable experiments
    variable selectedExperimentIndex

    if {$index < 0 || $index >= [llength $experiments]} { return }
    set selectedExperimentIndex $index
    set exp [lindex $experiments $index]

    foreach {var key} {
        expId id
        expName name
        expDomain domain
        expStatus status
        expDescription description
        expConfigPath configPath
        expWorkflowPath workflowPath
        expOutputDir outputDir
        expLogPath logPath
        expBaselinePath baselinePath
        expMetricsPath metricsPath
        expTags tags
        expNotes notes
        expCreatedAt createdAt
    } {
        set ::wb::$var [dict get $exp $key]
    }

    wb::populateExperimentNotesWidget
    wb::setStatus "esperimento selezionato"
}

proc wb::onExperimentTreeSelect {} {
    variable ui
    set tree $ui(expTree)
    set sel [$tree selection]
    if {$sel eq ""} { return }
    set item [lindex $sel 0]
    set index [$tree set $item 0]
    wb::loadExperimentIntoEditor $index
}

proc wb::buildExperimentDictFromEditor {} {
    wb::readExperimentNotesWidget

    if {[string trim $::wb::expId] eq ""} {
        set ::wb::expId [wb::nextExperimentId]
    }
    if {[string trim $::wb::expCreatedAt] eq ""} {
        set ::wb::expCreatedAt [wb::nowString]
    }

    return [dict create \
        id           $::wb::expId \
        name         $::wb::expName \
        domain       $::wb::expDomain \
        status       $::wb::expStatus \
        description  $::wb::expDescription \
        configPath   $::wb::expConfigPath \
        workflowPath $::wb::expWorkflowPath \
        outputDir    $::wb::expOutputDir \
        logPath      $::wb::expLogPath \
        baselinePath $::wb::expBaselinePath \
        metricsPath  $::wb::expMetricsPath \
        tags         $::wb::expTags \
        notes        $::wb::expNotes \
        createdAt    $::wb::expCreatedAt]
}

proc wb::newExperiment {} {
    variable selectedExperimentIndex
    set selectedExperimentIndex -1
    wb::clearExperimentEditor
    set ::wb::expId [wb::nextExperimentId]
    set ::wb::expCreatedAt [wb::nowString]
    wb::populateExperimentNotesWidget
    wb::setStatus "nuovo esperimento"
}

proc wb::saveCurrentExperiment {} {
    variable experiments
    variable selectedExperimentIndex

    if {[string trim $::wb::expName] eq ""} {
        tk_messageBox -icon warning -title "Validazione" -message "Il nome esperimento è obbligatorio."
        return
    }

    set exp [wb::buildExperimentDictFromEditor]

    if {$selectedExperimentIndex < 0} {
        lappend experiments $exp
        set selectedExperimentIndex [expr {[llength $experiments] - 1}]
    } else {
        set newList {}
        set i 0
        foreach old $experiments {
            if {$i == $selectedExperimentIndex} {
                lappend newList $exp
            } else {
                lappend newList $old
            }
            incr i
        }
        set experiments $newList
    }

    wb::refreshExperimentsTable
    wb::setStatus "esperimento salvato"
}

proc wb::deleteCurrentExperiment {} {
    variable experiments
    variable selectedExperimentIndex

    if {$selectedExperimentIndex < 0} {
        tk_messageBox -icon info -title "Elimina" -message "Seleziona un esperimento da eliminare."
        return
    }

    set ans [tk_messageBox -icon question -type yesno -title "Conferma" -message "Eliminare l'esperimento selezionato?"]
    if {$ans ne "yes"} { return }

    set newList {}
    set i 0
    foreach exp $experiments {
        if {$i != $selectedExperimentIndex} {
            lappend newList $exp
        }
        incr i
    }

    set experiments $newList
    set selectedExperimentIndex -1
    wb::clearExperimentEditor
    wb::populateExperimentNotesWidget
    wb::refreshExperimentsTable
    wb::setStatus "esperimento eliminato"
}

proc wb::browseSelectedExperimentOutput {} {
    if {[string trim $::wb::expOutputDir] eq ""} {
        tk_messageBox -icon info -title "Results" -message "Nessuna output dir associata."
        return
    }
    set ::wb::currentRoot $::wb::expOutputDir
    .resultsTab.top.rootEntry delete 0 end
    .resultsTab.top.rootEntry insert 0 $::wb::expOutputDir
    wb::populateResultsTree
    .nb select .resultsTab
    wb::setStatus "output esperimento aperto nel Result Browser"
}

proc wb::loadSelectedExperimentValidation {} {
    variable metricsData
    variable baselineData
    variable metricsFile
    variable baselineFile

    if {[string trim $::wb::expMetricsPath] eq ""} {
        tk_messageBox -icon info -title "Validation" -message "Nessun metrics file associato."
        return
    }

    if {[catch {
        set metricsData [wb::loadCsvAsDicts $::wb::expMetricsPath]
        set metricsFile $::wb::expMetricsPath
    } err]} {
        tk_messageBox -icon error -title "Errore metriche" -message $err
        return
    }

    .validationTab.top.metricsEntry delete 0 end
    .validationTab.top.metricsEntry insert 0 $metricsFile

    if {[string trim $::wb::expBaselinePath] ne "" && [file exists $::wb::expBaselinePath]} {
        if {[catch {
            set baselineData [wb::loadCsvAsDicts $::wb::expBaselinePath]
            set baselineFile $::wb::expBaselinePath
        } err]} {
            set baselineData {}
            set baselineFile ""
        }
    } else {
        set baselineData {}
        set baselineFile ""
    }

    .validationTab.top.baseEntry delete 0 end
    .validationTab.top.baseEntry insert 0 $baselineFile
    wb::refreshValidationTable
    .nb select .validationTab
    wb::setStatus "validation caricata dall'esperimento"
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

proc wb::matchResultFilter {path} {
    variable filterText
    set filter [string trim [string tolower $filterText]]
    if {$filter eq ""} { return 1 }

    set name [string tolower [file tail $path]]
    set ext [string tolower [file extension $path]]

    foreach token [split $filter ", "] {
        set token [string trim $token]
        if {$token eq ""} { continue }
        if {[string match ".*" $token]} {
            if {$ext eq $token} { return 1 }
        } else {
            if {[string first $token $name] >= 0} { return 1 }
        }
    }
    return 0
}

proc wb::clearResultsTree {} {
    variable ui
    set tree $ui(resTree)
    foreach item [$tree children {}] { $tree delete $item }
}

proc wb::insertResultPathRecursive {parent path} {
    variable ui
    set tree $ui(resTree)

    if {[file isdirectory $path]} {
        set id [$tree insert $parent end -text [file tail $path] -values [list $path dir]]
        foreach child [lsort -dictionary [glob -nocomplain -directory $path *]] {
            if {[file isdirectory $child]} {
                wb::insertResultPathRecursive $id $child
            } else {
                if {[wb::matchResultFilter $child]} {
                    $tree insert $id end -text [file tail $child] -values [list $child file]
                }
            }
        }
        return $id
    } else {
        if {[wb::matchResultFilter $path]} {
            return [$tree insert $parent end -text [file tail $path] -values [list $path file]]
        }
    }
    return ""
}

proc wb::populateResultsTree {} {
    variable currentRoot
    variable ui

    wb::clearResultsTree

    if {$currentRoot eq "" || ![file exists $currentRoot]} {
        wb::setStatus "nessuna root risultati selezionata"
        return
    }

    set tree $ui(resTree)
    set rootId [$tree insert {} end -text [file tail $currentRoot] -open 1 -values [list $currentRoot dir]]

    foreach child [lsort -dictionary [glob -nocomplain -directory $currentRoot *]] {
        if {[file isdirectory $child]} {
            wb::insertResultPathRecursive $rootId $child
        } else {
            if {[wb::matchResultFilter $child]} {
                $tree insert $rootId end -text [file tail $child] -values [list $child file]
            }
        }
    }

    wb::setStatus "Result Browser aggiornato"
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

proc wb::showResultsTextPreview {path} {
    variable ui
    if {[catch {
        set ch [open $path r]
        set content [read $ch 65536]
        close $ch
    } err]} {
        set content "Errore lettura file:\n$err"
    }

    $ui(resTextPreview) configure -state normal
    $ui(resTextPreview) delete 1.0 end
    $ui(resTextPreview) insert end $content
    $ui(resTextPreview) configure -state disabled
}

proc wb::showResultsImagePreview {path} {
    variable ui
    variable previewImage

    catch {image delete $previewImage}
    set previewImage ""

    if {[catch {
        set img [image create photo -file $path]
        set previewImage $img
        $ui(resImageLabel) configure -image $img
    } err]} {
        $ui(resTextPreview) configure -state normal
        $ui(resTextPreview) delete 1.0 end
        $ui(resTextPreview) insert end "Errore caricamento immagine:\n$err"
        $ui(resTextPreview) configure -state disabled
    }
}

proc wb::showResultsBinarySummary {path} {
    variable ui
    set ext [string tolower [file extension $path]]
    set msg "Anteprima non disponibile per questo tipo di file.\n\nEstensione: $ext\nAprilo esternamente per ispezione dettagliata."
    $ui(resTextPreview) configure -state normal
    $ui(resTextPreview) delete 1.0 end
    $ui(resTextPreview) insert end $msg
    $ui(resTextPreview) configure -state disabled
}

proc wb::updateResultsSelectionInfo {path} {
    variable ui
    variable selectedPath

    set selectedPath $path
    wb::clearResultsPreview

    if {$path eq "" || ![file exists $path]} { return }

    set kind [expr {[file isdirectory $path] ? "Directory" : "File"}]
    set size "-"
    if {![file isdirectory $path]} {
        set size [wb::humanSize [file size $path]]
    }
    set mtime [clock format [file mtime $path] -format "%Y-%m-%d %H:%M:%S"]

    $ui(resInfoPath) configure -text $path
    $ui(resInfoType) configure -text $kind
    $ui(resInfoSize) configure -text $size
    $ui(resInfoMtime) configure -text $mtime

    if {[file isdirectory $path]} {
        $ui(resTextPreview) configure -state normal
        $ui(resTextPreview) delete 1.0 end
        $ui(resTextPreview) insert end "Directory selezionata.\n\nUsa 'Apri esternamente' o naviga nei file."
        $ui(resTextPreview) configure -state disabled
        return
    }

    if {[wb::isImageFile $path]} {
        wb::showResultsImagePreview $path
    } elseif {[wb::isTextFile $path]} {
        wb::showResultsTextPreview $path
    } else {
        wb::showResultsBinarySummary $path
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

proc wb::chooseResultsRoot {} {
    variable currentRoot
    set d [tk_chooseDirectory -title "Seleziona cartella risultati"]
    if {$d eq ""} { return }
    set currentRoot $d
    .resultsTab.top.rootEntry delete 0 end
    .resultsTab.top.rootEntry insert 0 $d
    wb::populateResultsTree
}

proc wb::refreshResults {} {
    variable currentRoot
    set currentRoot [.resultsTab.top.rootEntry get]
    wb::populateResultsTree
}

proc wb::openExternalSelectedResult {} {
    variable selectedPath
    if {$selectedPath eq ""} { return }
    wb::openPath $selectedPath
}

proc wb::openSelectedResultParent {} {
    variable selectedPath
    if {$selectedPath eq ""} { return }
    if {[file isdirectory $selectedPath]} {
        wb::openPath $selectedPath
    } else {
        wb::openPath [file dirname $selectedPath]
    }
}

# ==================================================
# VALIDATION
# ==================================================
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

proc wb::overallValidationStatus {} {
    variable failCount
    variable warnCount
    if {$failCount > 0} { return "FAIL" }
    if {$warnCount > 0} { return "WARN" }
    return "PASS"
}

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

    set status "WARN"
    set numValue [wb::toNumber $value]
    set numMin   [wb::toNumber $minVal]
    set numMax   [wb::toNumber $maxVal]

    if {$numValue eq ""} {
        set status "FAIL"
    } else {
        set hasMin [expr {$numMin ne ""}]
        set hasMax [expr {$numMax ne ""}]
        if {!$hasMin && !$hasMax} {
            set status "WARN"
        } else {
            set ok 1
            if {$hasMin && $numValue < $numMin} { set ok 0 }
            if {$hasMax && $numValue > $numMax} { set ok 0 }
            if {$ok} { set status "PASS" } else { set status "FAIL" }
        }
    }

    set delta [wb::safeDelta $value $baseline]
    return [dict create metric $metric value $value baseline $baseline delta $delta min $minVal max $maxVal status $status]
}

proc wb::clearValidationTable {} {
    variable ui
    set tree $ui(valTree)
    foreach item [$tree children {}] { $tree delete $item }
}

proc wb::refreshValidationSummary {} {
    variable passCount
    variable warnCount
    variable failCount
    variable ui
    set overall [wb::overallValidationStatus]
    $ui(valSummary) configure -text "PASS=$passCount   WARN=$warnCount   FAIL=$failCount   =>   $overall"
}

proc wb::refreshValidationTable {} {
    variable metricsData
    variable ui
    variable passCount
    variable warnCount
    variable failCount

    wb::clearValidationTable
    set passCount 0
    set warnCount 0
    set failCount 0

    set baselineMap [wb::baselineMap]
    set tree $ui(valTree)

    foreach row $metricsData {
        set evalRow [wb::evaluateMetricRow $row $baselineMap]
        set status [dict get $evalRow status]

        switch -- $status {
            PASS { incr passCount }
            WARN { incr warnCount }
            FAIL { incr failCount }
        }

        set item [$tree insert {} end -values [list \
            [dict get $evalRow metric] \
            [dict get $evalRow value] \
            [dict get $evalRow baseline] \
            [dict get $evalRow delta] \
            [dict get $evalRow min] \
            [dict get $evalRow max] \
            [dict get $evalRow status]]]

        switch -- $status {
            PASS { $tree item $item -tags pass }
            WARN { $tree item $item -tags warn }
            FAIL { $tree item $item -tags fail }
        }
    }

    wb::refreshValidationSummary
    wb::setStatus "dashboard validazione aggiornato"
}

proc wb::onValidationTreeSelect {} {
    variable ui
    set tree $ui(valTree)
    set sel [$tree selection]
    if {$sel eq ""} { return }

    set item [lindex $sel 0]
    .validationTab.right.detail.metricV configure -text [$tree set $item 0]
    .validationTab.right.detail.valueV  configure -text [$tree set $item 1]
    .validationTab.right.detail.baseV   configure -text [$tree set $item 2]
    .validationTab.right.detail.deltaV  configure -text [$tree set $item 3]
    .validationTab.right.detail.minV    configure -text [$tree set $item 4]
    .validationTab.right.detail.maxV    configure -text [$tree set $item 5]
    .validationTab.right.detail.statusV configure -text [$tree set $item 6]
}

proc wb::openMetricsFile {} {
    variable metricsFile
    variable metricsData
    set f [tk_getOpenFile -title "Apri file metriche" -filetypes {{"CSV files" {.csv}} {"All files" {*}}}]
    if {$f eq ""} { return }
    if {[catch {
        set metricsData [wb::loadCsvAsDicts $f]
        set metricsFile $f
    } err]} {
        tk_messageBox -icon error -title "Errore" -message $err
        return
    }
    .validationTab.top.metricsEntry delete 0 end
    .validationTab.top.metricsEntry insert 0 $f
    wb::refreshValidationTable
}

proc wb::openBaselineFile {} {
    variable baselineFile
    variable baselineData
    set f [tk_getOpenFile -title "Apri file baseline" -filetypes {{"CSV files" {.csv}} {"All files" {*}}}]
    if {$f eq ""} { return }
    if {[catch {
        set baselineData [wb::loadCsvAsDicts $f]
        set baselineFile $f
    } err]} {
        tk_messageBox -icon error -title "Errore" -message $err
        return
    }
    .validationTab.top.baseEntry delete 0 end
    .validationTab.top.baseEntry insert 0 $f
    wb::refreshValidationTable
}

proc wb::reloadValidationFiles {} {
    variable metricsFile
    variable baselineFile
    variable metricsData
    variable baselineData

    if {$metricsFile eq ""} {
        tk_messageBox -icon info -title "Reload" -message "Nessun file metriche caricato."
        return
    }

    if {[catch {
        set metricsData [wb::loadCsvAsDicts $metricsFile]
        if {$baselineFile ne ""} {
            set baselineData [wb::loadCsvAsDicts $baselineFile]
        }
    } err]} {
        tk_messageBox -icon error -title "Errore" -message $err
        return
    }
    wb::refreshValidationTable
}

proc wb::loadValidationSampleData {} {
    variable metricsData
    variable baselineData
    variable metricsFile
    variable baselineFile

    set metricsFile ""
    set baselineFile ""

    set metricsData {
        {metric rmse value 1.24 min 0 max 2.0}
        {metric pd value 0.91 min 0.85 max 1.0}
        {metric pfa value 0.03 min 0 max 0.05}
        {metric latency_ms value 18 min 0 max 25}
        {metric coverage value 0.78 min 0.80 max 1.0}
    }

    set baselineData {
        {metric rmse value 1.10}
        {metric pd value 0.93}
        {metric pfa value 0.02}
        {metric latency_ms value 16}
        {metric coverage value 0.82}
    }

    .validationTab.top.metricsEntry delete 0 end
    .validationTab.top.baseEntry delete 0 end
    wb::refreshValidationTable
}

# ==================================================
# LAUNCHER
# ==================================================
proc wb::profileNames {} {
    variable launchProfiles
    set names {}
    foreach p $launchProfiles {
        lappend names [dict get $p name]
    }
    return $names
}

proc wb::findProfileByName {name} {
    variable launchProfiles
    foreach p $launchProfiles {
        if {[dict get $p name] eq $name} { return $p }
    }
    return ""
}

proc wb::autoSelectProfileForDomain {domain} {
    variable launchProfiles
    variable launchProfile
    foreach p $launchProfiles {
        if {[dict get $p domain] eq $domain} {
            set launchProfile [dict get $p name]
            return
        }
    }
}

proc wb::useExperimentInLauncher {} {
    if {[string trim $::wb::expConfigPath] eq ""} {
        tk_messageBox -icon info -title "Launcher" -message "L'esperimento non ha config associata."
        return
    }

    set ::wb::launchConfigPath $::wb::expConfigPath
    set ::wb::launchCaseName   $::wb::expName
    set ::wb::launchOutputRoot [expr {$::wb::expOutputDir eq "" ? "./runs" : $::wb::expOutputDir}]
    wb::autoSelectProfileForDomain $::wb::expDomain
    wb::updateLauncherCommandPreview
    .nb select .launcherTab
    wb::setStatus "esperimento inviato al Launcher"
}

proc wb::buildLauncherRunOutputDir {} {
    variable launchOutputRoot
    variable launchCaseName
    set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
    set caseName [string trim $launchCaseName]
    if {$caseName eq ""} { set caseName "run" }
    return [file join $launchOutputRoot "${caseName}_$ts"]
}

proc wb::buildLaunchCommand {} {
    variable launchProfile
    variable launchConfigPath
    variable launchInputData
    variable launchExtraArgs
    variable launchWorkdir

    set p [wb::findProfileByName $launchProfile]
    if {$p eq ""} {
        return [list {} ""]
    }

    set type      [dict get $p type]
    set launcher  [dict get $p launcher]
    set target    [dict get $p target]
    set workdir   [dict get $p workdir]
    set extra     [dict get $p extra_args]
    set outputDir [wb::buildLauncherRunOutputDir]

    set launchWorkdir $workdir
    set launchExtraArgs $extra

    set cmd {}
    switch -- $type {
        python_script {
            lappend cmd $launcher $target --config $launchConfigPath
            if {[string trim $launchInputData] ne ""} { lappend cmd --input $launchInputData }
            lappend cmd --output $outputDir
            foreach a [wb::splitArgs $extra] { lappend cmd $a }
        }
        cpp_executable {
            lappend cmd $target --config $launchConfigPath
            if {[string trim $launchInputData] ne ""} { lappend cmd --input $launchInputData }
            lappend cmd --output $outputDir
            foreach a [wb::splitArgs $extra] { lappend cmd $a }
        }
        hdl_runner {
            lappend cmd $launcher $target --config $launchConfigPath --output $outputDir
            foreach a [wb::splitArgs $extra] { lappend cmd $a }
        }
        matlab_function {
            set expr [format "%s('%s')" $target $launchConfigPath]
            lappend cmd $launcher -batch $expr
        }
    }
    return [list $cmd $outputDir]
}

proc wb::updateLauncherCommandPreview {} {
    variable ui
    lassign [wb::buildLaunchCommand] cmd outdir
    $ui(cmdPreview) configure -state normal
    $ui(cmdPreview) delete 1.0 end
    $ui(cmdPreview) insert end [join $cmd " "]
    if {$outdir ne ""} {
        $ui(cmdPreview) insert end "\n\nOutput dir: $outdir"
        $ui(cmdPreview) insert end "\nRuntime log: [file join $outdir run.log]"
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

proc wb::clearRuntimeLog {} {
    variable ui
    $ui(runtimeLog) delete 1.0 end
}

proc wb::openRuntimeLogFile {outdir} {
    variable runtimeLogChan
    variable lastRunLogFile

    set lastRunLogFile [file join $outdir run.log]
    if {$runtimeLogChan ne ""} {
        catch {close $runtimeLogChan}
    }
    set runtimeLogChan [open $lastRunLogFile w]
}

proc wb::closeRuntimeLogFile {} {
    variable runtimeLogChan
    if {$runtimeLogChan ne ""} {
        catch {close $runtimeLogChan}
        set runtimeLogChan ""
    }
}

proc wb::startRun {} {
    variable running
    variable processChan
    variable processPid
    variable launchWorkdir
    variable lastRunOutputDir

    if {$running} {
        tk_messageBox -icon warning -title "Attenzione" -message "C'è già un processo in esecuzione."
        return
    }

    if {[string trim $::wb::launchConfigPath] eq ""} {
        tk_messageBox -icon warning -title "Config mancante" -message "Specifica prima una config."
        return
    }

    lassign [wb::buildLaunchCommand] cmd outdir
    set lastRunOutputDir $outdir

    if {[llength $cmd] == 0} {
        tk_messageBox -icon error -title "Errore" -message "Comando vuoto."
        return
    }

    file mkdir $outdir
    wb::openRuntimeLogFile $outdir
    wb::clearRuntimeLog

    set oldDir [pwd]
    if {$launchWorkdir ne "" && [file isdirectory $launchWorkdir]} {
        cd $launchWorkdir
    }

    if {[catch {
        set processChan [open "|[list {*}$cmd] 2>@1" r]
        fconfigure $processChan -blocking 0 -buffering line
        fileevent $processChan readable [list wb::onLauncherProcessReadable $processChan]
        set processPid [pid $processChan]
        set running 1
    } err]} {
        cd $oldDir
        wb::closeRuntimeLogFile
        tk_messageBox -icon error -title "Errore avvio" -message "Impossibile avviare il processo:\n$err"
        wb::logRuntime "ERROR: avvio processo fallito: $err"
        return
    }

    cd $oldDir
    wb::logRuntime "OK: processo avviato"
    wb::logRuntime "CMD: [join $cmd { }]"
    wb::logRuntime "Output dir: $outdir"
    .nb select .runtimeTab
    wb::setStatus "launcher in esecuzione"
}

proc wb::onLauncherProcessReadable {chan} {
    variable running
    variable processChan
    variable processPid

    if {[eof $chan]} {
        set closeMsg ""
        if {[catch {close $chan} err]} {
            set closeMsg $err
        }

        if {$closeMsg ne ""} {
            wb::logRuntime "WARN: processo terminato: $closeMsg"
        } else {
            wb::logRuntime "OK: processo terminato correttamente"
        }

        set running 0
        set processChan ""
        set processPid ""
        wb::closeRuntimeLogFile
        wb::setStatus "launcher terminato"
        return
    }

    if {[gets $chan line] >= 0} {
        set u [string toupper $line]
        if {[string match "*ERROR*" $u] || [string match "*FATAL*" $u]} {
            wb::logRuntime "ERROR: $line"
        } elseif {[string match "*WARN*" $u] || [string match "*WARNING*" $u]} {
            wb::logRuntime "WARN: $line"
        } elseif {[string match "*INFO*" $u]} {
            wb::logRuntime "OK: $line"
        } else {
            wb::logRuntime $line
        }
    }
}

proc wb::stopRun {} {
    variable running
    variable processChan
    variable processPid

    if {!$running} {
        wb::setStatus "nessun processo attivo"
        return
    }

    if {$processPid ne ""} {
        catch {exec kill $processPid}
        wb::logRuntime "WARN: segnale di stop inviato al PID=$processPid"
    }
    catch {close $processChan}

    set running 0
    set processChan ""
    set processPid ""
    wb::closeRuntimeLogFile
    wb::setStatus "launcher fermato"
}

proc wb::browseLastRunOutput {} {
    variable lastRunOutputDir
    if {[string trim $lastRunOutputDir] eq ""} {
        tk_messageBox -icon info -title "Results" -message "Nessun output recente disponibile."
        return
    }
    set ::wb::currentRoot $lastRunOutputDir
    .resultsTab.top.rootEntry delete 0 end
    .resultsTab.top.rootEntry insert 0 $lastRunOutputDir
    wb::populateResultsTree
    .nb select .resultsTab
}

proc wb::analyzeLastLauncherLog {} {
    variable lastRunLogFile
    if {[string trim $lastRunLogFile] eq "" || ![file exists $lastRunLogFile]} {
        tk_messageBox -icon info -title "Log Analyzer" -message "Nessun run.log recente disponibile."
        return
    }
    wb::anLoadFile $lastRunLogFile
    .nb select .analyzerTab
}

# ==================================================
# WORKFLOW
# ==================================================
proc wb::wfNodeTag {id} { return "wf_node_$id" }
proc wb::wfNodeRectTag {id} { return "wf_node_rect_$id" }
proc wb::wfNodeTextTag {id} { return "wf_node_text_$id" }

proc wb::wfTypeColor {type} {
    switch -- $type {
        Start      { return "#d9fdd3" }
        Scenario   { return "#e8f0ff" }
        Config     { return "#fff2cc" }
        Process    { return "#ddebf7" }
        Decision   { return "#fce5cd" }
        Validation { return "#ead1dc" }
        Log        { return "#f4cccc" }
        Output     { return "#d0e0e3" }
        End        { return "#d9ead3" }
        default    { return "#eeeeee" }
    }
}

proc wb::wfNodeLabel {id} {
    variable wfNodes
    set name [dict get $wfNodes($id) name]
    set type [dict get $wfNodes($id) type]
    return "$name\n<$type>"
}

proc wb::wfCenterOfNode {id} {
    variable wfNodes
    return [list [dict get $wfNodes($id) x] [dict get $wfNodes($id) y]]
}

proc wb::wfGetNodeAt {x y} {
    variable ui
    set c $ui(wfCanvas)
    set items [$c find overlapping $x $y $x $y]
    foreach item [lreverse $items] {
        foreach tag [$c gettags $item] {
            if {[regexp {^wf_node_([0-9]+)$} $tag -> id]} {
                return $id
            }
        }
    }
    return ""
}

proc wb::wfRefreshNodeVisualState {nodeId} {
    variable wfNodes
    variable wfSelectedNode
    variable ui

    if {![info exists wfNodes($nodeId)]} { return }
    set rectId [dict get $wfNodes($nodeId) rect]
    set state  [dict get $wfNodes($nodeId) state]
    set c $ui(wfCanvas)

    switch -- $state {
        idle {
            if {$wfSelectedNode eq $nodeId} {
                $c itemconfigure $rectId -outline blue -width 3
            } else {
                $c itemconfigure $rectId -outline black -width 2
            }
        }
        running { $c itemconfigure $rectId -outline blue -width 4 }
        ok      { $c itemconfigure $rectId -outline darkgreen -width 4 }
        failed  { $c itemconfigure $rectId -outline red -width 4 }
        skipped { $c itemconfigure $rectId -outline gray50 -width 3 }
        default { $c itemconfigure $rectId -outline black -width 2 }
    }
}

proc wb::wfSetNodeState {nodeId state {msg ""} {exitCode ""}} {
    variable wfNodes
    variable wfSelectedNode
    if {![info exists wfNodes($nodeId)]} { return }

    dict set wfNodes($nodeId) state $state
    dict set wfNodes($nodeId) lastMessage $msg
    dict set wfNodes($nodeId) lastExitCode $exitCode
    dict set wfNodes($nodeId) lastRunTs [wb::nowString]
    wb::wfRefreshNodeVisualState $nodeId

    if {$wfSelectedNode eq $nodeId} {
        wb::wfLoadSelectedNodeProperties
    }
}

proc wb::wfClearAll {} {
    variable wfNodes
    variable wfEdges
    variable wfSelectedNode
    variable wfConnectFrom
    variable wfNextNodeId
    variable ui

    $ui(wfCanvas) delete all
    catch {unset wfNodes}
    array set wfNodes {}
    set wfEdges {}
    set wfSelectedNode ""
    set wfConnectFrom ""
    set wfNextNodeId 1
    wb::wfLoadSelectedNodeProperties
    wb::setStatus "workflow svuotato"
}

proc wb::wfCreateNode {x y {type "Process"} {name ""}} {
    variable wfNodes
    variable wfNextNodeId
    variable wfNodeWidth
    variable wfNodeHeight
    variable ui

    set id $wfNextNodeId
    incr wfNextNodeId

    if {$name eq ""} { set name "$type $id" }

    set halfW [expr {$wfNodeWidth / 2}]
    set halfH [expr {$wfNodeHeight / 2}]
    set x1 [expr {$x - $halfW}]
    set y1 [expr {$y - $halfH}]
    set x2 [expr {$x + $halfW}]
    set y2 [expr {$y + $halfH}]

    set rect [$ui(wfCanvas) create rectangle $x1 $y1 $x2 $y2 \
        -fill [wb::wfTypeColor $type] -outline black -width 2 \
        -tags [list [wb::wfNodeTag $id] [wb::wfNodeRectTag $id]]]

    set text [$ui(wfCanvas) create text $x $y \
        -text "$name\n<$type>" -justify center -font "TkDefaultFont 10" \
        -tags [list [wb::wfNodeTag $id] [wb::wfNodeTextTag $id]]]

    set wfNodes($id) [dict create \
        id $id x $x y $y name $name type $type \
        launcherProfile "" configPath "" logPath "" workDir "." extraArgs "" notes "" \
        lastOutputDir "" state idle lastMessage "" lastExitCode "" lastRunTs "" \
        rect $rect text $text]

    wb::wfSelectNode $id
    return $id
}

proc wb::wfEdgeExists {from to} {
    variable wfEdges
    foreach e $wfEdges {
        if {[dict get $e from] == $from && [dict get $e to] == $to} { return 1 }
    }
    return 0
}

proc wb::wfCreateEdge {from to} {
    variable wfEdges
    variable ui
    if {$from eq "" || $to eq "" || $from == $to} { return }
    if {[wb::wfEdgeExists $from $to]} { return }

    lassign [wb::wfCenterOfNode $from] x1 y1
    lassign [wb::wfCenterOfNode $to] x2 y2

    set lineId [$ui(wfCanvas) create line $x1 $y1 $x2 $y2 -arrow last -width 2 -fill "#555555"]
    $ui(wfCanvas) lower $lineId
    lappend wfEdges [dict create from $from to $to lineId $lineId]
}

proc wb::wfRedrawEdgesForNode {nodeId} {
    variable wfEdges
    variable ui
    foreach e $wfEdges {
        set from [dict get $e from]
        set to   [dict get $e to]
        if {$from == $nodeId || $to == $nodeId} {
            lassign [wb::wfCenterOfNode $from] x1 y1
            lassign [wb::wfCenterOfNode $to]   x2 y2
            $ui(wfCanvas) coords [dict get $e lineId] $x1 $y1 $x2 $y2
        }
    }
}

proc wb::wfClearSelection {} {
    variable wfSelectedNode
    if {$wfSelectedNode ne ""} {
        wb::wfRefreshNodeVisualState $wfSelectedNode
    }
    set wfSelectedNode ""
}

proc wb::wfLoadSelectedNodeProperties {} {
    variable wfSelectedNode
    variable wfNodes

    if {$wfSelectedNode eq "" || ![info exists wfNodes($wfSelectedNode)]} {
        foreach var {
            wfPropName wfPropLauncherProfile wfPropConfigPath wfPropLogPath wfPropWorkDir
            wfPropExtraArgs wfPropNotes wfPropState wfPropLastMessage wfPropLastExitCode wfPropLastRunTs
        } { set ::wb::$var "" }
        set ::wb::wfPropType "Process"
        if {[winfo exists .workflowTab.right.props.tnotes]} {
            .workflowTab.right.props.tnotes delete 1.0 end
        }
        return
    }

    foreach {var key} {
        wfPropName name
        wfPropType type
        wfPropLauncherProfile launcherProfile
        wfPropConfigPath configPath
        wfPropLogPath logPath
        wfPropWorkDir workDir
        wfPropExtraArgs extraArgs
        wfPropNotes notes
        wfPropState state
        wfPropLastMessage lastMessage
        wfPropLastExitCode lastExitCode
        wfPropLastRunTs lastRunTs
    } {
        set ::wb::$var [dict get $wfNodes($wfSelectedNode) $key]
    }

    if {[winfo exists .workflowTab.right.props.tnotes]} {
        .workflowTab.right.props.tnotes delete 1.0 end
        .workflowTab.right.props.tnotes insert end $::wb::wfPropNotes
    }
}

proc wb::wfSelectNode {id} {
    variable wfSelectedNode
    variable wfNodes
    wb::wfClearSelection
    if {$id eq ""} { return }
    set wfSelectedNode $id
    wb::wfRefreshNodeVisualState $id
    wb::wfLoadSelectedNodeProperties
    wb::setStatus "nodo workflow selezionato: [dict get $wfNodes($id) name]"
}

proc wb::wfApplyNodeProperties {} {
    variable wfSelectedNode
    variable wfNodes
    variable ui
    if {$wfSelectedNode eq "" || ![info exists wfNodes($wfSelectedNode)]} { return }

    set ::wb::wfPropNotes [string trim [.workflowTab.right.props.tnotes get 1.0 end]]

    foreach {var key} {
        wfPropName name
        wfPropType type
        wfPropLauncherProfile launcherProfile
        wfPropConfigPath configPath
        wfPropLogPath logPath
        wfPropWorkDir workDir
        wfPropExtraArgs extraArgs
        wfPropNotes notes
    } {
        dict set wfNodes($wfSelectedNode) $key [set ::wb::$var]
    }

    $ui(wfCanvas) itemconfigure [dict get $wfNodes($wfSelectedNode) rect] -fill [wb::wfTypeColor $::wb::wfPropType]
    $ui(wfCanvas) itemconfigure [dict get $wfNodes($wfSelectedNode) text] -text [wb::wfNodeLabel $wfSelectedNode]
    wb::wfRefreshNodeVisualState $wfSelectedNode
}

proc wb::wfCanvasClick {x y} {
    variable wfMode
    variable wfConnectFrom
    variable wfPendingNodeType

    set id [wb::wfGetNodeAt $x $y]

    switch -- $wfMode {
        add {
            wb::wfCreateNode $x $y $wfPendingNodeType
            set ::wb::wfMode "select"
        }
        connect {
            if {$id eq ""} { return }
            if {$wfConnectFrom eq ""} {
                set wfConnectFrom $id
                wb::wfSelectNode $id
            } else {
                wb::wfCreateEdge $wfConnectFrom $id
                set wfConnectFrom ""
                set ::wb::wfMode "select"
            }
        }
        default {
            if {$id ne ""} {
                wb::wfSelectNode $id
            } else {
                wb::wfClearSelection
                wb::wfLoadSelectedNodeProperties
            }
        }
    }
}

proc wb::wfDragStart {x y} {
    variable wfMode
    variable wfDragNode
    variable wfDragLastX
    variable wfDragLastY
    if {$wfMode ne "select"} { return }
    set id [wb::wfGetNodeAt $x $y]
    if {$id ne ""} {
        set wfDragNode $id
        set wfDragLastX $x
        set wfDragLastY $y
        wb::wfSelectNode $id
    }
}

proc wb::wfDragMove {x y} {
    variable wfDragNode
    variable wfDragLastX
    variable wfDragLastY
    variable wfNodes
    variable ui
    if {$wfDragNode eq ""} { return }

    set dx [expr {$x - $wfDragLastX}]
    set dy [expr {$y - $wfDragLastY}]
    set wfDragLastX $x
    set wfDragLastY $y

    $ui(wfCanvas) move [dict get $wfNodes($wfDragNode) rect] $dx $dy
    $ui(wfCanvas) move [dict get $wfNodes($wfDragNode) text] $dx $dy
    dict incr wfNodes($wfDragNode) x $dx
    dict incr wfNodes($wfDragNode) y $dy
    wb::wfRedrawEdgesForNode $wfDragNode
}

proc wb::wfDragEnd {} {
    set ::wb::wfDragNode ""
}

proc wb::wfDeleteSelectedNode {} {
    variable wfSelectedNode
    variable wfNodes
    variable wfEdges
    variable ui

    if {$wfSelectedNode eq "" || ![info exists wfNodes($wfSelectedNode)]} { return }
    set id $wfSelectedNode

    $ui(wfCanvas) delete [dict get $wfNodes($id) rect]
    $ui(wfCanvas) delete [dict get $wfNodes($id) text]
    unset wfNodes($id)

    set newEdges {}
    foreach e $wfEdges {
        if {[dict get $e from] == $id || [dict get $e to] == $id} {
            $ui(wfCanvas) delete [dict get $e lineId]
        } else {
            lappend newEdges $e
        }
    }
    set wfEdges $newEdges

    set wfSelectedNode ""
    wb::wfLoadSelectedNodeProperties
}

proc wb::wfIncomingCount {nodeId} {
    variable wfEdges
    set c 0
    foreach e $wfEdges {
        if {[dict get $e to] == $nodeId} { incr c }
    }
    return $c
}

proc wb::wfOutgoingNodes {nodeId} {
    variable wfEdges
    set out {}
    foreach e $wfEdges {
        if {[dict get $e from] == $nodeId} {
            lappend out [dict get $e to]
        }
    }
    return $out
}

proc wb::wfFindStartNodes {} {
    variable wfNodes
    set starts {}
    foreach id [array names wfNodes] {
        if {[wb::wfIncomingCount $id] == 0} {
            lappend starts $id
        }
    }
    return [lsort -integer $starts]
}

proc wb::wfTopologicalWalk {} {
    variable wfNodes
    if {[array size wfNodes] == 0} { return {} }

    set queue [wb::wfFindStartNodes]
    set visited {}
    set ordered {}

    while {[llength $queue] > 0} {
        set current [lindex $queue 0]
        set queue [lrange $queue 1 end]

        if {[lsearch -exact $visited $current] >= 0} { continue }
        lappend visited $current
        lappend ordered $current

        foreach nxt [wb::wfOutgoingNodes $current] {
            if {[lsearch -exact $visited $nxt] < 0} {
                lappend queue $nxt
            }
        }
    }
    return $ordered
}

proc wb::wfResetAllNodeStates {} {
    variable wfNodes
    foreach id [array names wfNodes] {
        foreach {k v} {state idle lastMessage "" lastExitCode "" lastRunTs ""} {
            dict set wfNodes($id) $k $v
        }
        wb::wfRefreshNodeVisualState $id
    }
    wb::wfLoadSelectedNodeProperties
}

proc wb::wfBuildRunOutputDir {nodeId} {
    variable wfNodes
    set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
    set safe [string map {" " "_" "/" "_" "\\" "_"} [dict get $wfNodes($nodeId) name]]
    return [file join runs $safe $ts]
}

proc wb::wfBuildCommandForNode {nodeId} {
    variable wfNodes
    variable launchProfiles

    if {![info exists wfNodes($nodeId)]} {
        return [list {} "" ""]
    }

    set type [dict get $wfNodes($nodeId) type]
    set configPath [dict get $wfNodes($nodeId) configPath]
    set profile [dict get $wfNodes($nodeId) launcherProfile]
    set workDir [dict get $wfNodes($nodeId) workDir]
    set extraArgs [dict get $wfNodes($nodeId) extraArgs]
    set outputDir [wb::wfBuildRunOutputDir $nodeId]

    if {$type ne "Process"} {
        return [list {} $outputDir $workDir]
    }

    set p [wb::findProfileByName $profile]
    if {$p eq ""} {
        return [list {} $outputDir $workDir]
    }

    set ptype [dict get $p type]
    set launcher [dict get $p launcher]
    set target [dict get $p target]
    set pwork [dict get $p workdir]
    set pextra [dict get $p extra_args]

    set cmd {}
    switch -- $ptype {
        python_script {
            lappend cmd $launcher $target
            if {$configPath ne ""} { lappend cmd --config $configPath }
            lappend cmd --output $outputDir
            foreach a [wb::splitArgs $pextra] { lappend cmd $a }
            foreach a [wb::splitArgs $extraArgs] { lappend cmd $a }
        }
        cpp_executable {
            lappend cmd $target
            if {$configPath ne ""} { lappend cmd --config $configPath }
            lappend cmd --output $outputDir
            foreach a [wb::splitArgs $pextra] { lappend cmd $a }
            foreach a [wb::splitArgs $extraArgs] { lappend cmd $a }
        }
        hdl_runner {
            lappend cmd $launcher $target
            if {$configPath ne ""} { lappend cmd --config $configPath }
            lappend cmd --output $outputDir
            foreach a [wb::splitArgs $pextra] { lappend cmd $a }
            foreach a [wb::splitArgs $extraArgs] { lappend cmd $a }
        }
        matlab_function {
            if {$configPath eq ""} {
                set expr "$target()"
            } else {
                set expr [format "%s('%s')" $target $configPath]
            }
            lappend cmd $launcher -batch $expr
        }
    }

    if {$workDir eq ""} { set workDir $pwork }
    return [list $cmd $outputDir $workDir]
}

proc wb::wfExecuteNode {nodeId} {
    variable wfNodes
    variable wfRunning
    variable wfProcessChan
    variable wfProcessPid
    variable wfRunningNode

    if {$wfRunning} { return }
    if {![info exists wfNodes($nodeId)]} { return }

    set type [dict get $wfNodes($nodeId) type]
    set name [dict get $wfNodes($nodeId) name]

    switch -- $type {
        Config {
            set path [dict get $wfNodes($nodeId) configPath]
            if {$path eq "" || ![file exists $path]} {
                wb::wfSetNodeState $nodeId failed "Config non trovata" 1
                return
            }
            wb::openPath $path
            wb::wfSetNodeState $nodeId ok "Config aperta" 0
            return
        }
        Log {
            set path [dict get $wfNodes($nodeId) logPath]
            if {$path eq "" || ![file exists $path]} {
                wb::wfSetNodeState $nodeId failed "Log non trovato" 1
                return
            }
            wb::openPath $path
            wb::wfSetNodeState $nodeId ok "Log aperto" 0
            return
        }
        Output {
            set path [dict get $wfNodes($nodeId) lastOutputDir]
            if {$path eq "" || ![file exists $path]} {
                wb::wfSetNodeState $nodeId failed "Output non disponibile" 1
                return
            }
            wb::openPath $path
            wb::wfSetNodeState $nodeId ok "Output aperto" 0
            return
        }
        Process {
            lassign [wb::wfBuildCommandForNode $nodeId] cmd outdir workdir
            if {[llength $cmd] == 0} {
                wb::wfSetNodeState $nodeId failed "Nodo Process non configurato" 1
                return
            }

            file mkdir $outdir
            dict set wfNodes($nodeId) lastOutputDir $outdir
            wb::wfSetNodeState $nodeId running "Nodo in esecuzione" ""

            set oldDir [pwd]
            if {$workdir ne "" && [file isdirectory $workdir]} {
                cd $workdir
            }

            if {[catch {
                set wfProcessChan [open "|[list {*}$cmd] 2>@1" r]
                fconfigure $wfProcessChan -blocking 0 -buffering line
                fileevent $wfProcessChan readable [list wb::wfOnProcessReadable $wfProcessChan]
                set wfProcessPid [pid $wfProcessChan]
                set wfRunning 1
                set wfRunningNode $nodeId
            } err]} {
                cd $oldDir
                wb::wfSetNodeState $nodeId failed "Avvio fallito: $err" 1
                return
            }

            cd $oldDir
            wb::setStatus "workflow: nodo in esecuzione $name"
            return
        }
        default {
            wb::wfSetNodeState $nodeId ok "Azione locale completata" 0
            return
        }
    }
}

proc wb::wfOnProcessReadable {chan} {
    variable wfRunning
    variable wfProcessChan
    variable wfProcessPid
    variable wfRunningNode
    variable wfExecutionQueue
    variable wfNodes

    if {[eof $chan]} {
        set closeMsg ""
        if {[catch {close $chan} err]} {
            set closeMsg $err
        }

        if {$wfRunningNode ne "" && [info exists wfNodes($wfRunningNode)]} {
            if {$closeMsg ne ""} {
                wb::wfSetNodeState $wfRunningNode failed $closeMsg 1
                set wfExecutionQueue {}
            } else {
                wb::wfSetNodeState $wfRunningNode ok "Terminato correttamente" 0
            }
        }

        set wfRunning 0
        set wfProcessChan ""
        set wfProcessPid ""
        set wfRunningNode ""

        if {[llength $wfExecutionQueue] > 0} {
            after 200 wb::wfExecuteNextInQueue
        } else {
            wb::setStatus "workflow terminato"
        }
        return
    }

    if {[gets $chan line] >= 0} {
        # minimal: no dedicated workflow log pane, push into main status only lightly
        if {[string match "*ERROR*" [string toupper $line]]} {
            wb::setStatus "workflow: $line"
        }
    }
}

proc wb::wfExecuteNextInQueue {} {
    variable wfExecutionQueue
    if {[llength $wfExecutionQueue] == 0} {
        return
    }
    set nodeId [lindex $wfExecutionQueue 0]
    set wfExecutionQueue [lrange $wfExecutionQueue 1 end]
    wb::wfExecuteNode $nodeId
}

proc wb::wfRunWorkflowSequence {} {
    variable wfExecutionQueue
    variable wfNodes

    wb::wfResetAllNodeStates
    set ordered [wb::wfTopologicalWalk]
    set queue {}
    foreach nodeId $ordered {
        if {[dict get $wfNodes($nodeId) type] eq "Process"} {
            lappend queue $nodeId
        }
    }
    set wfExecutionQueue $queue
    wb::wfExecuteNextInQueue
}

proc wb::wfExecuteSelectedNode {} {
    variable wfSelectedNode
    if {$wfSelectedNode eq ""} { return }
    wb::wfExecuteNode $wfSelectedNode
}

proc wb::wfStopExecution {} {
    variable wfRunning
    variable wfProcessChan
    variable wfProcessPid
    variable wfRunningNode
    variable wfExecutionQueue

    set wfExecutionQueue {}
    if {!$wfRunning} { return }

    if {$wfProcessPid ne ""} {
        catch {exec kill $wfProcessPid}
    }
    catch {close $wfProcessChan}

    if {$wfRunningNode ne ""} {
        wb::wfSetNodeState $wfRunningNode failed "Interrotto manualmente" 1
    }

    set wfRunning 0
    set wfProcessChan ""
    set wfProcessPid ""
    set wfRunningNode ""
    wb::setStatus "workflow fermato"
}

proc wb::wfBrowseSelectedOutput {} {
    variable wfSelectedNode
    variable wfNodes
    if {$wfSelectedNode eq "" || ![info exists wfNodes($wfSelectedNode)]} { return }
    set path [dict get $wfNodes($wfSelectedNode) lastOutputDir]
    if {$path eq ""} { return }
    set ::wb::currentRoot $path
    .resultsTab.top.rootEntry delete 0 end
    .resultsTab.top.rootEntry insert 0 $path
    wb::populateResultsTree
    .nb select .resultsTab
}

proc wb::wfAnalyzeSelectedLog {} {
    variable wfSelectedNode
    variable wfNodes
    if {$wfSelectedNode eq "" || ![info exists wfNodes($wfSelectedNode)]} { return }
    set path [dict get $wfNodes($wfSelectedNode) logPath]
    if {$path eq "" || ![file exists $path]} { return }
    wb::anLoadFile $path
    .nb select .analyzerTab
}

proc wb::wfLoadSample {} {
    wb::wfClearAll

    set a [wb::wfCreateNode 120 120 Start "Start"]
    set b [wb::wfCreateNode 290 120 Scenario "Scenario"]
    set c [wb::wfCreateNode 470 120 Config "Radar Config"]
    set d [wb::wfCreateNode 660 120 Process "Preprocess"]
    set e [wb::wfCreateNode 850 120 Process "Detect"]
    set f [wb::wfCreateNode 850 260 Process "Track"]
    set g [wb::wfCreateNode 1040 120 Validation "Validate"]
    set h [wb::wfCreateNode 1220 120 Output "Export"]
    set i [wb::wfCreateNode 1040 260 Log "Run Log"]
    set j [wb::wfCreateNode 1220 260 End "End"]

    dict set ::wb::wfNodes($c) configPath "configs/radar_case_01.json"
    dict set ::wb::wfNodes($d) launcherProfile "Radar Python Chain"
    dict set ::wb::wfNodes($d) configPath "configs/radar_case_01.json"
    dict set ::wb::wfNodes($e) launcherProfile "Radar Python Chain"
    dict set ::wb::wfNodes($e) configPath "configs/radar_case_01.json"
    dict set ::wb::wfNodes($f) launcherProfile "Radar Python Chain"
    dict set ::wb::wfNodes($f) configPath "configs/radar_case_01.json"
    dict set ::wb::wfNodes($i) logPath "runs/example/run.log"

    foreach n [list $c $d $e $f $i] {
        $::wb::ui(wfCanvas) itemconfigure [dict get $::wb::wfNodes($n) text] -text [wb::wfNodeLabel $n]
    }

    wb::wfCreateEdge $a $b
    wb::wfCreateEdge $b $c
    wb::wfCreateEdge $c $d
    wb::wfCreateEdge $d $e
    wb::wfCreateEdge $e $f
    wb::wfCreateEdge $e $g
    wb::wfCreateEdge $f $g
    wb::wfCreateEdge $g $h
    wb::wfCreateEdge $g $i
    wb::wfCreateEdge $h $j
    wb::wfCreateEdge $i $j

    wb::wfClearSelection
    wb::wfLoadSelectedNodeProperties
}

# ==================================================
# LOG ANALYZER
# ==================================================
proc wb::configureAnalyzerTags {} {
    variable ui
    $ui(anViewer) tag configure error -foreground red
    $ui(anViewer) tag configure warn  -foreground darkorange3
    $ui(anViewer) tag configure info  -foreground darkgreen
    $ui(anViewer) tag configure debug -foreground blue
    $ui(anViewer) tag configure other -foreground black
    $ui(anViewer) tag configure hit   -background yellow
}

proc wb::anClassify {line} {
    set u [string toupper $line]
    if {[string match "*ERROR*" $u] || [string match "*FATAL*" $u]} { return error }
    if {[string match "*WARN*" $u] || [string match "*WARNING*" $u]} { return warn }
    if {[string match "*DEBUG*" $u] || [string match "*TRACE*" $u]} { return debug }
    if {[string match "*INFO*" $u] || [string match "*OK:*" $u]} { return info }
    return other
}

proc wb::anSeverityEnabled {sev} {
    variable analyzerFilterError
    variable analyzerFilterWarn
    variable analyzerFilterInfo
    variable analyzerFilterDebug
    switch -- $sev {
        error { return $analyzerFilterError }
        warn  { return $analyzerFilterWarn }
        info  { return $analyzerFilterInfo }
        debug { return $analyzerFilterDebug }
        other { return 1 }
    }
    return 1
}

proc wb::anLoadFile {f} {
    variable analyzerCurrentFile
    variable analyzerRawLines

    if {[catch {
        set ch [open $f r]
        set content [read $ch]
        close $ch
    } err]} {
        tk_messageBox -icon error -title "Errore" -message "Impossibile aprire il log:\n$err"
        return
    }

    set analyzerCurrentFile $f
    set analyzerRawLines [split $content "\n"]
    wb::anApplyFilters
}

proc wb::anOpenFile {} {
    set f [tk_getOpenFile -title "Apri file di log" -filetypes {{"Log files" {.log .txt .out}} {"All files" {*}}}]
    if {$f eq ""} { return }
    wb::anLoadFile $f
}

proc wb::anApplyFilters {} {
    variable analyzerRawLines
    variable analyzerVisibleLines
    variable analyzerSearchText
    variable analyzerOnlyMatching
    variable ui

    set analyzerVisibleLines {}
    foreach line $analyzerRawLines {
        set sev [wb::anClassify $line]
        set sevOk [wb::anSeverityEnabled $sev]
        set txtOk [expr {[string trim $analyzerSearchText] eq "" || [string first [string tolower $analyzerSearchText] [string tolower $line]] >= 0}]
        if {$analyzerOnlyMatching} {
            if {$sevOk && $txtOk} { lappend analyzerVisibleLines $line }
        } else {
            if {$sevOk} { lappend analyzerVisibleLines $line }
        }
    }
    wb::anRender
    wb::anRefreshCritical
    wb::anUpdateStats
}

proc wb::anRender {} {
    variable ui
    variable analyzerVisibleLines
    variable analyzerSearchText

    $ui(anViewer) configure -state normal
    $ui(anViewer) delete 1.0 end

    set lineNo 1
    foreach line $analyzerVisibleLines {
        set sev [wb::anClassify $line]
        $ui(anViewer) insert end $line $sev
        $ui(anViewer) insert end "\n"

        if {[string trim $analyzerSearchText] ne ""} {
            set start "$lineNo.0"
            set end "$lineNo.end"
            set pos [$ui(anViewer) search -nocase $analyzerSearchText $start $end]
            while {$pos ne ""} {
                set posEnd "$pos + [string length $analyzerSearchText] chars"
                $ui(anViewer) tag add hit $pos $posEnd
                set pos [$ui(anViewer) search -nocase $analyzerSearchText $posEnd $end]
            }
        }
        incr lineNo
    }
    $ui(anViewer) configure -state disabled
}

proc wb::anRefreshCritical {} {
    variable ui
    variable analyzerVisibleLines
    $ui(anCritical) delete 0 end
    set lineNo 1
    foreach line $analyzerVisibleLines {
        set sev [wb::anClassify $line]
        if {$sev eq "error" || $sev eq "warn"} {
            set short $line
            if {[string length $short] > 120} {
                set short "[string range $short 0 116]..."
            }
            $ui(anCritical) insert end "$lineNo | $short"
        }
        incr lineNo
    }
}

proc wb::anJumpToCritical {} {
    variable ui
    set sel [$ui(anCritical) curselection]
    if {$sel eq ""} { return }
    set item [$ui(anCritical) get [lindex $sel 0]]
    if {[regexp {^([0-9]+)\s+\|} $item -> lineNo]} {
        $ui(anViewer) see "${lineNo}.0"
        $ui(anViewer) tag remove sel 1.0 end
        $ui(anViewer) tag add sel "${lineNo}.0" "${lineNo}.end"
    }
}

proc wb::anFindNext {} {
    variable ui
    variable analyzerSearchText
    if {[string trim $analyzerSearchText] eq ""} { return }
    set cur [$ui(anViewer) index insert]
    set pos [$ui(anViewer) search -nocase $analyzerSearchText "$cur + 1 chars" end]
    if {$pos eq ""} {
        set pos [$ui(anViewer) search -nocase $analyzerSearchText 1.0 end]
    }
    if {$pos ne ""} {
        set posEnd "$pos + [string length $analyzerSearchText] chars"
        $ui(anViewer) see $pos
        $ui(anViewer) tag remove sel 1.0 end
        $ui(anViewer) tag add sel $pos $posEnd
        $ui(anViewer) mark set insert $pos
    }
}

proc wb::anSaveFiltered {} {
    variable analyzerVisibleLines
    set f [tk_getSaveFile -title "Salva log filtrato" -defaultextension ".log" -filetypes {{"Log files" {.log .txt}} {"All files" {*}}}]
    if {$f eq ""} { return }
    catch {
        set ch [open $f w]
        puts -nonewline $ch [join $analyzerVisibleLines "\n"]
        close $ch
    }
}

proc wb::anUpdateStats {} {
    variable analyzerVisibleLines
    set e 0; set w 0; set i 0; set d 0; set o 0
    foreach line $analyzerVisibleLines {
        switch -- [wb::anClassify $line] {
            error { incr e }
            warn  { incr w }
            info  { incr i }
            debug { incr d }
            other { incr o }
        }
    }
    .analyzerTab.stats configure -text "ERROR=$e   WARN=$w   INFO=$i   DEBUG=$d   OTHER=$o"
}

# ==================================================
# UI BUILDERS
# ==================================================
proc wb::buildExperimentsTab {} {
    variable ui

    ttk::panedwindow .experimentsTab.pw -orient horizontal
    pack .experimentsTab.pw -fill both -expand 1

    ttk::frame .experimentsTab.left -padding 6
    ttk::frame .experimentsTab.right -padding 6
    .experimentsTab.pw add .experimentsTab.left -weight 3
    .experimentsTab.pw add .experimentsTab.right -weight 2

    ttk::frame .experimentsTab.left.filters -padding 4
    pack .experimentsTab.left.filters -fill x

    ttk::label .experimentsTab.left.filters.dl -text "Dominio:"
    ttk::combobox .experimentsTab.left.filters.dc -state readonly \
        -values {all radar satellite underwater hdl} \
        -textvariable wb::filterDomain

    ttk::label .experimentsTab.left.filters.sl -text "Stato:"
    ttk::combobox .experimentsTab.left.filters.sc -state readonly \
        -values {all draft ready running completed validated failed archived} \
        -textvariable wb::filterStatus

    ttk::label .experimentsTab.left.filters.ql -text "Cerca:"
    ttk::entry .experimentsTab.left.filters.qe -textvariable wb::searchText
    ttk::button .experimentsTab.left.filters.apply -text "Applica filtri" -command wb::refreshExperimentsTable

    pack .experimentsTab.left.filters.apply -side right -padx 3
    pack .experimentsTab.left.filters.qe -side right -padx 3
    pack .experimentsTab.left.filters.ql -side right -padx 3
    pack .experimentsTab.left.filters.sc -side right -padx 3
    pack .experimentsTab.left.filters.sl -side right -padx 3
    pack .experimentsTab.left.filters.dc -side right -padx 3
    pack .experimentsTab.left.filters.dl -side right -padx 3

    ttk::labelframe .experimentsTab.left.box -text "Esperimenti" -padding 6
    pack .experimentsTab.left.box -fill both -expand 1

    set ui(expTree) [ttk::treeview .experimentsTab.left.box.tree \
        -columns {idx id name domain status createdAt} -show headings -selectmode browse]

    foreach {col txt w} {
        idx "#" 50
        id "ID" 90
        name "Nome" 280
        domain "Dominio" 110
        status "Stato" 110
        createdAt "Creato" 150
    } {
        $ui(expTree) heading $col -text $txt
        $ui(expTree) column $col -width $w
    }

    ttk::scrollbar .experimentsTab.left.box.vsb -orient vertical -command "$ui(expTree) yview"
    ttk::scrollbar .experimentsTab.left.box.hsb -orient horizontal -command "$ui(expTree) xview"
    $ui(expTree) configure -yscrollcommand ".experimentsTab.left.box.vsb set" -xscrollcommand ".experimentsTab.left.box.hsb set"

    grid $ui(expTree) -row 0 -column 0 -sticky nsew
    grid .experimentsTab.left.box.vsb -row 0 -column 1 -sticky ns
    grid .experimentsTab.left.box.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .experimentsTab.left.box 0 -weight 1
    grid columnconfigure .experimentsTab.left.box 0 -weight 1

    bind $ui(expTree) <<TreeviewSelect>> wb::onExperimentTreeSelect
    bind .experimentsTab.left.filters.qe <Return> {wb::refreshExperimentsTable}

    ttk::labelframe .experimentsTab.right.form -text "Dettagli esperimento" -padding 10
    pack .experimentsTab.right.form -fill both -expand 1

    grid columnconfigure .experimentsTab.right.form 1 -weight 1

    foreach {row lbl var} {
        0 "ID:" expId
        1 "Nome:" expName
        4 "Descrizione:" expDescription
        12 "Tags:" expTags
        13 "Creato:" expCreatedAt
    } {
        ttk::label .experimentsTab.right.form.l$row -text $lbl
        ttk::entry .experimentsTab.right.form.e$row -textvariable wb::$var
        grid .experimentsTab.right.form.l$row -row $row -column 0 -sticky w -pady 4
        grid .experimentsTab.right.form.e$row -row $row -column 1 -columnspan 2 -sticky ew -pady 4
    }

    ttk::label .experimentsTab.right.form.l2 -text "Dominio:"
    ttk::combobox .experimentsTab.right.form.c2 -state readonly -values {radar satellite underwater hdl} -textvariable wb::expDomain
    grid .experimentsTab.right.form.l2 -row 2 -column 0 -sticky w -pady 4
    grid .experimentsTab.right.form.c2 -row 2 -column 1 -columnspan 2 -sticky ew -pady 4

    ttk::label .experimentsTab.right.form.l3 -text "Stato:"
    ttk::combobox .experimentsTab.right.form.c3 -state readonly -values {draft ready running completed validated failed archived} -textvariable wb::expStatus
    grid .experimentsTab.right.form.l3 -row 3 -column 0 -sticky w -pady 4
    grid .experimentsTab.right.form.c3 -row 3 -column 1 -columnspan 2 -sticky ew -pady 4

    foreach {row lbl var cmd} {
        5  "Config path:"   expConfigPath   wb::chooseResultsRoot
    } {
        # placeholder
    }

    proc ::wb::_buildPathRow {parent row lbl var browseCmd} {
        ttk::label $parent.lx$row -text $lbl
        ttk::entry $parent.ex$row -textvariable wb::$var
        ttk::button $parent.bx$row -text "..." -width 3 -command $browseCmd
        grid $parent.lx$row -row $row -column 0 -sticky w -pady 4
        grid $parent.ex$row -row $row -column 1 -sticky ew -pady 4
        grid $parent.bx$row -row $row -column 2 -sticky ew -padx 4
    }

    ::wb::_buildPathRow .experimentsTab.right.form 5  "Config path:"   expConfigPath   {set f [tk_getOpenFile -title "Seleziona config file"]; if {$f ne ""} {set ::wb::expConfigPath $f}}
    ::wb::_buildPathRow .experimentsTab.right.form 6  "Workflow path:" expWorkflowPath {set f [tk_getOpenFile -title "Seleziona workflow file" -filetypes {{"Workflow files" {.wflow}} {"All files" {*}}}]; if {$f ne ""} {set ::wb::expWorkflowPath $f}}
    ::wb::_buildPathRow .experimentsTab.right.form 7  "Output dir:"    expOutputDir    {set d [tk_chooseDirectory -title "Seleziona output directory"]; if {$d ne ""} {set ::wb::expOutputDir $d}}
    ::wb::_buildPathRow .experimentsTab.right.form 8  "Log path:"      expLogPath      {set f [tk_getOpenFile -title "Seleziona log file" -filetypes {{"Log files" {.log .txt .out}} {"All files" {*}}}]; if {$f ne ""} {set ::wb::expLogPath $f}}
    ::wb::_buildPathRow .experimentsTab.right.form 9  "Baseline path:" expBaselinePath {set f [tk_getOpenFile -title "Seleziona baseline file"]; if {$f ne ""} {set ::wb::expBaselinePath $f}}
    ::wb::_buildPathRow .experimentsTab.right.form 10 "Metrics path:"  expMetricsPath  {set f [tk_getOpenFile -title "Seleziona metrics file" -filetypes {{"CSV files" {.csv}} {"All files" {*}}}]; if {$f ne ""} {set ::wb::expMetricsPath $f}}

    ttk::label .experimentsTab.right.form.l14 -text "Note:"
    text .experimentsTab.right.form.tnotes -height 7 -width 30 -wrap word
    grid .experimentsTab.right.form.l14 -row 14 -column 0 -sticky nw -pady 4
    grid .experimentsTab.right.form.tnotes -row 14 -column 1 -columnspan 2 -sticky ew -pady 4

    ttk::labelframe .experimentsTab.right.actions -text "Azioni rapide" -padding 10
    pack .experimentsTab.right.actions -fill x -pady 10

    ttk::button .experimentsTab.right.actions.bc -text "Apri config" -command {wb::openPath $::wb::expConfigPath}
    ttk::button .experimentsTab.right.actions.bw -text "Apri workflow" -command {wb::openPath $::wb::expWorkflowPath}
    ttk::button .experimentsTab.right.actions.bo -text "Apri output" -command {wb::openPath $::wb::expOutputDir}
    ttk::button .experimentsTab.right.actions.bl -text "Apri log" -command {wb::openPath $::wb::expLogPath}
    ttk::button .experimentsTab.right.actions.bb -text "Apri baseline" -command {wb::openPath $::wb::expBaselinePath}
    ttk::button .experimentsTab.right.actions.br -text "Vai a Results" -command wb::browseSelectedExperimentOutput
    ttk::button .experimentsTab.right.actions.bv -text "Vai a Validation" -command wb::loadSelectedExperimentValidation
    ttk::button .experimentsTab.right.actions.bla -text "Usa nel Launcher" -command wb::useExperimentInLauncher
    ttk::button .experimentsTab.right.actions.bwf -text "Apre workflow nel canvas" -command {if {$::wb::expWorkflowPath ne ""} {wb::openPath $::wb::expWorkflowPath}}

    pack .experimentsTab.right.actions.bc .experimentsTab.right.actions.bw \
         .experimentsTab.right.actions.bo .experimentsTab.right.actions.bl \
         .experimentsTab.right.actions.bb .experimentsTab.right.actions.br \
         .experimentsTab.right.actions.bv .experimentsTab.right.actions.bla \
         .experimentsTab.right.actions.bwf -fill x -pady 2
}

proc wb::buildResultsTab {} {
    variable ui

    ttk::frame .resultsTab.top -padding 6
    pack .resultsTab.top -fill x

    ttk::button .resultsTab.top.chooseBtn -text "Apri cartella" -command wb::chooseResultsRoot
    ttk::button .resultsTab.top.refreshBtn -text "Refresh" -command wb::refreshResults
    ttk::button .resultsTab.top.openBtn -text "Apri esternamente" -command wb::openExternalSelectedResult
    ttk::button .resultsTab.top.parentBtn -text "Apri cartella padre" -command wb::openSelectedResultParent

    ttk::label .resultsTab.top.rootLabel -text "Root:"
    entry .resultsTab.top.rootEntry

    ttk::label .resultsTab.top.filterLabel -text "Filtro:"
    ttk::entry .resultsTab.top.filterEntry -textvariable wb::filterText
    ttk::button .resultsTab.top.filterBtn -text "Applica filtro" -command wb::populateResultsTree

    pack .resultsTab.top.chooseBtn .resultsTab.top.refreshBtn .resultsTab.top.openBtn .resultsTab.top.parentBtn -side left -padx 3
    pack .resultsTab.top.filterBtn -side right -padx 3
    pack .resultsTab.top.filterEntry -side right -padx 3
    pack .resultsTab.top.filterLabel -side right -padx 3
    pack .resultsTab.top.rootEntry -side right -fill x -expand 1 -padx 3
    pack .resultsTab.top.rootLabel -side right -padx 3

    ttk::panedwindow .resultsTab.pw -orient horizontal
    pack .resultsTab.pw -fill both -expand 1

    ttk::frame .resultsTab.left -padding 6
    ttk::frame .resultsTab.right -padding 6
    .resultsTab.pw add .resultsTab.left -weight 2
    .resultsTab.pw add .resultsTab.right -weight 3

    ttk::labelframe .resultsTab.left.box -text "Output tree" -padding 6
    pack .resultsTab.left.box -fill both -expand 1

    set ui(resTree) [ttk::treeview .resultsTab.left.box.tree -columns {path kind} -show tree -selectmode browse]
    ttk::scrollbar .resultsTab.left.box.vsb -orient vertical -command "$ui(resTree) yview"
    ttk::scrollbar .resultsTab.left.box.hsb -orient horizontal -command "$ui(resTree) xview"
    $ui(resTree) configure -yscrollcommand ".resultsTab.left.box.vsb set" -xscrollcommand ".resultsTab.left.box.hsb set"

    grid $ui(resTree) -row 0 -column 0 -sticky nsew
    grid .resultsTab.left.box.vsb -row 0 -column 1 -sticky ns
    grid .resultsTab.left.box.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .resultsTab.left.box 0 -weight 1
    grid columnconfigure .resultsTab.left.box 0 -weight 1

    bind $ui(resTree) <<TreeviewSelect>> wb::onResultsTreeSelect
    bind .resultsTab.top.filterEntry <Return> {wb::populateResultsTree}

    ttk::labelframe .resultsTab.right.info -text "Info file" -padding 10
    pack .resultsTab.right.info -fill x
    grid columnconfigure .resultsTab.right.info 1 -weight 1

    foreach {row lbl name} {
        0 "Path:" resInfoPath
        1 "Tipo:" resInfoType
        2 "Dimensione:" resInfoSize
        3 "Modifica:" resInfoMtime
    } {
        ttk::label .resultsTab.right.info.l$row -text $lbl
        ttk::label .resultsTab.right.info.v$row -text "" -wraplength 700 -justify left
        grid .resultsTab.right.info.l$row -row $row -column 0 -sticky w -pady 3
        grid .resultsTab.right.info.v$row -row $row -column 1 -sticky w -pady 3
        set ui($name) .resultsTab.right.info.v$row
    }

    ttk::labelframe .resultsTab.right.preview -text "Preview" -padding 8
    pack .resultsTab.right.preview -fill both -expand 1 -pady 8

    ttk::notebook .resultsTab.right.preview.nb
    pack .resultsTab.right.preview.nb -fill both -expand 1

    ttk::frame .resultsTab.right.preview.textTab
    ttk::frame .resultsTab.right.preview.imageTab

    .resultsTab.right.preview.nb add .resultsTab.right.preview.textTab -text "Text"
    .resultsTab.right.preview.nb add .resultsTab.right.preview.imageTab -text "Image"

    set ui(resTextPreview) [text .resultsTab.right.preview.textTab.txt -wrap none -state disabled]
    ttk::scrollbar .resultsTab.right.preview.textTab.vsb -orient vertical -command "$ui(resTextPreview) yview"
    ttk::scrollbar .resultsTab.right.preview.textTab.hsb -orient horizontal -command "$ui(resTextPreview) xview"
    $ui(resTextPreview) configure -yscrollcommand ".resultsTab.right.preview.textTab.vsb set" -xscrollcommand ".resultsTab.right.preview.textTab.hsb set"

    grid $ui(resTextPreview) -row 0 -column 0 -sticky nsew
    grid .resultsTab.right.preview.textTab.vsb -row 0 -column 1 -sticky ns
    grid .resultsTab.right.preview.textTab.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .resultsTab.right.preview.textTab 0 -weight 1
    grid columnconfigure .resultsTab.right.preview.textTab 0 -weight 1

    set ui(resImageLabel) [label .resultsTab.right.preview.imageTab.img -anchor center]
    pack $ui(resImageLabel) -fill both -expand 1
}

proc wb::buildValidationTab {} {
    variable ui

    ttk::frame .validationTab.top -padding 6
    pack .validationTab.top -fill x

    ttk::button .validationTab.top.openMetrics -text "Apri metriche" -command wb::openMetricsFile
    ttk::button .validationTab.top.openBase    -text "Apri baseline" -command wb::openBaselineFile
    ttk::button .validationTab.top.reload      -text "Ricarica" -command wb::reloadValidationFiles
    ttk::button .validationTab.top.sample      -text "Sample" -command wb::loadValidationSampleData

    ttk::label .validationTab.top.metricsL -text "Metriche:"
    entry .validationTab.top.metricsEntry
    ttk::label .validationTab.top.baseL -text "Baseline:"
    entry .validationTab.top.baseEntry

    pack .validationTab.top.openMetrics .validationTab.top.openBase .validationTab.top.reload .validationTab.top.sample -side left -padx 4
    pack .validationTab.top.baseEntry -side right -fill x -expand 1 -padx 3
    pack .validationTab.top.baseL -side right -padx 3
    pack .validationTab.top.metricsEntry -side right -fill x -expand 1 -padx 3
    pack .validationTab.top.metricsL -side right -padx 3

    ttk::panedwindow .validationTab.pw -orient horizontal
    pack .validationTab.pw -fill both -expand 1

    ttk::frame .validationTab.left -padding 6
    ttk::frame .validationTab.right -padding 6
    .validationTab.pw add .validationTab.left -weight 4
    .validationTab.pw add .validationTab.right -weight 2

    ttk::labelframe .validationTab.left.box -text "Metriche" -padding 6
    pack .validationTab.left.box -fill both -expand 1

    set ui(valTree) [ttk::treeview .validationTab.left.box.tree \
        -columns {metric value baseline delta min max status} -show headings -selectmode browse]

    foreach {col txt w} {
        metric "Metric" 180
        value "Value" 100
        baseline "Baseline" 100
        delta "Delta" 100
        min "Min" 80
        max "Max" 80
        status "Status" 90
    } {
        $ui(valTree) heading $col -text $txt
        $ui(valTree) column $col -width $w -anchor center
    }

    ttk::scrollbar .validationTab.left.box.vsb -orient vertical -command "$ui(valTree) yview"
    ttk::scrollbar .validationTab.left.box.hsb -orient horizontal -command "$ui(valTree) xview"
    $ui(valTree) configure -yscrollcommand ".validationTab.left.box.vsb set" -xscrollcommand ".validationTab.left.box.hsb set"

    grid $ui(valTree) -row 0 -column 0 -sticky nsew
    grid .validationTab.left.box.vsb -row 0 -column 1 -sticky ns
    grid .validationTab.left.box.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .validationTab.left.box 0 -weight 1
    grid columnconfigure .validationTab.left.box 0 -weight 1

    bind $ui(valTree) <<TreeviewSelect>> wb::onValidationTreeSelect
    $ui(valTree) tag configure pass -foreground darkgreen
    $ui(valTree) tag configure warn -foreground darkorange3
    $ui(valTree) tag configure fail -foreground red

    ttk::labelframe .validationTab.right.detail -text "Dettaglio metrica" -padding 10
    pack .validationTab.right.detail -fill x
    grid columnconfigure .validationTab.right.detail 1 -weight 1

    foreach {row lbl var} {
        0 "Metric:" metricV
        1 "Value:" valueV
        2 "Baseline:" baseV
        3 "Delta:" deltaV
        4 "Min:" minV
        5 "Max:" maxV
        6 "Status:" statusV
    } {
        ttk::label .validationTab.right.detail.l$row -text $lbl
        ttk::label .validationTab.right.detail.$var -text "" -wraplength 320 -justify left
        grid .validationTab.right.detail.l$row -row $row -column 0 -sticky w -pady 4
        grid .validationTab.right.detail.$var -row $row -column 1 -sticky w -pady 4
    }

    set ui(valSummary) [ttk::label .validationTab.summary -text "PASS=0   WARN=0   FAIL=0   =>   PASS" -padding 6]
    pack .validationTab.summary -fill x
}

proc wb::buildLauncherTab {} {
    variable ui

    ttk::labelframe .launcherTab.box -text "Parametri launcher" -padding 10
    pack .launcherTab.box -fill x

    grid columnconfigure .launcherTab.box 1 -weight 1

    ttk::label .launcherTab.box.l1 -text "Profilo:"
    ttk::combobox .launcherTab.box.c1 -state readonly -values [wb::profileNames] -textvariable wb::launchProfile
    ttk::label .launcherTab.box.l2 -text "Config path:"
    ttk::entry .launcherTab.box.e2 -textvariable wb::launchConfigPath
    ttk::label .launcherTab.box.l3 -text "Case name:"
    ttk::entry .launcherTab.box.e3 -textvariable wb::launchCaseName
    ttk::label .launcherTab.box.l4 -text "Input data:"
    ttk::entry .launcherTab.box.e4 -textvariable wb::launchInputData
    ttk::label .launcherTab.box.l5 -text "Output root:"
    ttk::entry .launcherTab.box.e5 -textvariable wb::launchOutputRoot
    ttk::label .launcherTab.box.l6 -text "Workdir:"
    ttk::entry .launcherTab.box.e6 -textvariable wb::launchWorkdir
    ttk::label .launcherTab.box.l7 -text "Extra args:"
    ttk::entry .launcherTab.box.e7 -textvariable wb::launchExtraArgs

    for {set r 1} {$r <= 7} {incr r} {
        grid .launcherTab.box.l$r -row [expr {$r-1}] -column 0 -sticky w -pady 4
        if {$r == 1} {
            grid .launcherTab.box.c1 -row 0 -column 1 -sticky ew -pady 4
        } else {
            grid .launcherTab.box.e$r -row [expr {$r-1}] -column 1 -sticky ew -pady 4
        }
    }

    ttk::frame .launcherTab.actions -padding 6
    pack .launcherTab.actions -fill x

    ttk::button .launcherTab.actions.run -text "Avvia run" -command wb::startRun
    ttk::button .launcherTab.actions.stop -text "Stop" -command wb::stopRun
    ttk::button .launcherTab.actions.out -text "Vai a Results ultimo output" -command wb::browseLastRunOutput
    ttk::button .launcherTab.actions.log -text "Vai a Log Analyzer ultimo log" -command wb::analyzeLastLauncherLog

    pack .launcherTab.actions.run .launcherTab.actions.stop .launcherTab.actions.out .launcherTab.actions.log -side left -padx 4

    ttk::labelframe .launcherTab.cmd -text "Comando finale" -padding 8
    pack .launcherTab.cmd -fill both -expand 1 -pady 8

    set ui(cmdPreview) [text .launcherTab.cmd.txt -height 8 -wrap word]
    $ui(cmdPreview) configure -state disabled
    pack $ui(cmdPreview) -fill both -expand 1
}

proc wb::buildRuntimeTab {} {
    variable ui
    ttk::labelframe .runtimeTab.box -text "Runtime log live" -padding 8
    pack .runtimeTab.box -fill both -expand 1

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

proc wb::buildWorkflowTab {} {
    variable ui

    ttk::frame .workflowTab.toolbar -padding 6
    pack .workflowTab.toolbar -fill x

    ttk::button .workflowTab.toolbar.sel -text "Seleziona" -command {set ::wb::wfMode select}
    ttk::button .workflowTab.toolbar.add -text "Nuovo nodo" -command {set ::wb::wfMode add}
    ttk::button .workflowTab.toolbar.conn -text "Collega" -command {set ::wb::wfMode connect}
    ttk::button .workflowTab.toolbar.del -text "Elimina nodo" -command wb::wfDeleteSelectedNode
    ttk::button .workflowTab.toolbar.runone -text "Esegui nodo" -command wb::wfExecuteSelectedNode
    ttk::button .workflowTab.toolbar.runall -text "Esegui workflow" -command wb::wfRunWorkflowSequence
    ttk::button .workflowTab.toolbar.reset -text "Reset stati" -command wb::wfResetAllNodeStates
    ttk::button .workflowTab.toolbar.stop -text "Stop" -command wb::wfStopExecution
    ttk::button .workflowTab.toolbar.sample -text "Sample" -command wb::wfLoadSample

    ttk::label .workflowTab.toolbar.typeL -text "Tipo nodo:"
    ttk::combobox .workflowTab.toolbar.typeC -state readonly \
        -values {Start Scenario Config Process Decision Validation Log Output End} \
        -textvariable wb::wfPendingNodeType

    pack .workflowTab.toolbar.sel .workflowTab.toolbar.add .workflowTab.toolbar.conn \
         .workflowTab.toolbar.del .workflowTab.toolbar.runone .workflowTab.toolbar.runall \
         .workflowTab.toolbar.reset .workflowTab.toolbar.stop .workflowTab.toolbar.sample \
         -side left -padx 3
    pack .workflowTab.toolbar.typeC -side right -padx 4
    pack .workflowTab.toolbar.typeL -side right -padx 4

    ttk::panedwindow .workflowTab.pw -orient horizontal
    pack .workflowTab.pw -fill both -expand 1

    ttk::frame .workflowTab.left -padding 6
    ttk::frame .workflowTab.right -padding 6
    .workflowTab.pw add .workflowTab.left -weight 4
    .workflowTab.pw add .workflowTab.right -weight 1

    ttk::frame .workflowTab.left.wrap
    pack .workflowTab.left.wrap -fill both -expand 1

    set ui(wfCanvas) [canvas .workflowTab.left.wrap.c -background white -scrollregion {0 0 2600 1800}]
    ttk::scrollbar .workflowTab.left.wrap.vsb -orient vertical -command "$ui(wfCanvas) yview"
    ttk::scrollbar .workflowTab.left.wrap.hsb -orient horizontal -command "$ui(wfCanvas) xview"
    $ui(wfCanvas) configure -yscrollcommand ".workflowTab.left.wrap.vsb set" -xscrollcommand ".workflowTab.left.wrap.hsb set"

    grid $ui(wfCanvas) -row 0 -column 0 -sticky nsew
    grid .workflowTab.left.wrap.vsb -row 0 -column 1 -sticky ns
    grid .workflowTab.left.wrap.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .workflowTab.left.wrap 0 -weight 1
    grid columnconfigure .workflowTab.left.wrap 0 -weight 1

    ttk::labelframe .workflowTab.right.props -text "Proprietà nodo" -padding 10
    pack .workflowTab.right.props -fill x
    grid columnconfigure .workflowTab.right.props 1 -weight 1

    foreach {row lbl var} {
        0 "Nome:" wfPropName
        4 "Log path:" wfPropLogPath
        5 "Work dir:" wfPropWorkDir
        6 "Extra args:" wfPropExtraArgs
    } {
        ttk::label .workflowTab.right.props.l$row -text $lbl
        ttk::entry .workflowTab.right.props.e$row -textvariable wb::$var
        grid .workflowTab.right.props.l$row -row $row -column 0 -sticky w -pady 4
        grid .workflowTab.right.props.e$row -row $row -column 1 -columnspan 2 -sticky ew -pady 4
    }

    ttk::label .workflowTab.right.props.l1 -text "Tipo:"
    ttk::combobox .workflowTab.right.props.c1 -state readonly -values {Start Scenario Config Process Decision Validation Log Output End} -textvariable wb::wfPropType
    grid .workflowTab.right.props.l1 -row 1 -column 0 -sticky w -pady 4
    grid .workflowTab.right.props.c1 -row 1 -column 1 -columnspan 2 -sticky ew -pady 4

    ttk::label .workflowTab.right.props.l2 -text "Launcher profile:"
    ttk::combobox .workflowTab.right.props.c2 -values [wb::profileNames] -textvariable wb::wfPropLauncherProfile
    grid .workflowTab.right.props.l2 -row 2 -column 0 -sticky w -pady 4
    grid .workflowTab.right.props.c2 -row 2 -column 1 -columnspan 2 -sticky ew -pady 4

    ttk::label .workflowTab.right.props.l3 -text "Config path:"
    ttk::entry .workflowTab.right.props.e3 -textvariable wb::wfPropConfigPath
    grid .workflowTab.right.props.l3 -row 3 -column 0 -sticky w -pady 4
    grid .workflowTab.right.props.e3 -row 3 -column 1 -columnspan 2 -sticky ew -pady 4

    ttk::label .workflowTab.right.props.l7 -text "Note:"
    text .workflowTab.right.props.tnotes -height 6 -width 28 -wrap word
    grid .workflowTab.right.props.l7 -row 7 -column 0 -sticky nw -pady 4
    grid .workflowTab.right.props.tnotes -row 7 -column 1 -columnspan 2 -sticky ew -pady 4

    ttk::button .workflowTab.right.props.apply -text "Applica proprietà" -command wb::wfApplyNodeProperties
    grid .workflowTab.right.props.apply -row 8 -column 0 -columnspan 3 -sticky ew -pady 8

    ttk::labelframe .workflowTab.right.runtime -text "Stato runtime" -padding 10
    pack .workflowTab.right.runtime -fill x -pady 8
    grid columnconfigure .workflowTab.right.runtime 1 -weight 1

    foreach {row lbl var} {
        0 "State:" wfPropState
        1 "Last message:" wfPropLastMessage
        2 "Exit code:" wfPropLastExitCode
        3 "Last run:" wfPropLastRunTs
    } {
        ttk::label .workflowTab.right.runtime.l$row -text $lbl
        ttk::entry .workflowTab.right.runtime.e$row -textvariable wb::$var -state readonly
        grid .workflowTab.right.runtime.l$row -row $row -column 0 -sticky w -pady 3
        grid .workflowTab.right.runtime.e$row -row $row -column 1 -sticky ew -pady 3
    }

    ttk::frame .workflowTab.right.actions -padding 4
    pack .workflowTab.right.actions -fill x -pady 6
    ttk::button .workflowTab.right.actions.cfg -text "Apri config" -command {if {$::wb::wfPropConfigPath ne ""} {wb::openPath $::wb::wfPropConfigPath}}
    ttk::button .workflowTab.right.actions.log -text "Vai a Log Analyzer" -command wb::wfAnalyzeSelectedLog
    ttk::button .workflowTab.right.actions.out -text "Vai a Results output" -command wb::wfBrowseSelectedOutput
    pack .workflowTab.right.actions.cfg .workflowTab.right.actions.log .workflowTab.right.actions.out -fill x -pady 2

    bind $ui(wfCanvas) <Button-1>        {wb::wfCanvasClick [%W canvasx %x] [%W canvasy %y]}
    bind $ui(wfCanvas) <ButtonPress-1>   {wb::wfDragStart  [%W canvasx %x] [%W canvasy %y]}
    bind $ui(wfCanvas) <B1-Motion>       {wb::wfDragMove   [%W canvasx %x] [%W canvasy %y]}
    bind $ui(wfCanvas) <ButtonRelease-1> {wb::wfDragEnd}
}

proc wb::buildAnalyzerTab {} {
    variable ui

    ttk::frame .analyzerTab.top -padding 4
    pack .analyzerTab.top -fill x

    ttk::button .analyzerTab.top.open  -text "Apri log" -command wb::anOpenFile
    ttk::button .analyzerTab.top.last  -text "Analizza ultimo log launcher" -command wb::analyzeLastLauncherLog
    ttk::button .analyzerTab.top.save  -text "Salva filtrato" -command wb::anSaveFiltered
    ttk::label  .analyzerTab.top.searchL -text "Cerca:"
    ttk::entry  .analyzerTab.top.searchE -textvariable wb::analyzerSearchText
    ttk::button .analyzerTab.top.find  -text "Trova" -command wb::anFindNext
    ttk::button .analyzerTab.top.apply -text "Applica filtri" -command wb::anApplyFilters

    pack .analyzerTab.top.open .analyzerTab.top.last .analyzerTab.top.save -side left -padx 4
    pack .analyzerTab.top.apply .analyzerTab.top.find -side right -padx 4
    pack .analyzerTab.top.searchE -side right -padx 4
    pack .analyzerTab.top.searchL -side right -padx 4

    ttk::frame .analyzerTab.filters -padding 4
    pack .analyzerTab.filters -fill x
    ttk::checkbutton .analyzerTab.filters.err  -text "ERROR" -variable wb::analyzerFilterError
    ttk::checkbutton .analyzerTab.filters.warn -text "WARN"  -variable wb::analyzerFilterWarn
    ttk::checkbutton .analyzerTab.filters.info -text "INFO"  -variable wb::analyzerFilterInfo
    ttk::checkbutton .analyzerTab.filters.dbg  -text "DEBUG" -variable wb::analyzerFilterDebug
    ttk::checkbutton .analyzerTab.filters.match -text "Solo matching" -variable wb::analyzerOnlyMatching
    pack .analyzerTab.filters.err .analyzerTab.filters.warn .analyzerTab.filters.info .analyzerTab.filters.dbg .analyzerTab.filters.match -side left -padx 6

    ttk::panedwindow .analyzerTab.pw -orient horizontal
    pack .analyzerTab.pw -fill both -expand 1

    ttk::frame .analyzerTab.left -padding 6
    ttk::frame .analyzerTab.right -padding 6
    .analyzerTab.pw add .analyzerTab.left -weight 1
    .analyzerTab.pw add .analyzerTab.right -weight 4

    ttk::labelframe .analyzerTab.left.box -text "Eventi critici" -padding 6
    pack .analyzerTab.left.box -fill both -expand 1
    set ui(anCritical) [listbox .analyzerTab.left.box.lb -exportselection 0]
    ttk::scrollbar .analyzerTab.left.box.sb -orient vertical -command "$ui(anCritical) yview"
    $ui(anCritical) configure -yscrollcommand ".analyzerTab.left.box.sb set"
    grid $ui(anCritical) -row 0 -column 0 -sticky nsew
    grid .analyzerTab.left.box.sb -row 0 -column 1 -sticky ns
    grid rowconfigure .analyzerTab.left.box 0 -weight 1
    grid columnconfigure .analyzerTab.left.box 0 -weight 1

    ttk::labelframe .analyzerTab.right.box -text "Viewer log" -padding 6
    pack .analyzerTab.right.box -fill both -expand 1
    set ui(anViewer) [text .analyzerTab.right.box.txt -wrap none]
    ttk::scrollbar .analyzerTab.right.box.vsb -orient vertical -command "$ui(anViewer) yview"
    ttk::scrollbar .analyzerTab.right.box.hsb -orient horizontal -command "$ui(anViewer) xview"
    $ui(anViewer) configure -yscrollcommand ".analyzerTab.right.box.vsb set" -xscrollcommand ".analyzerTab.right.box.hsb set" -state disabled
    grid $ui(anViewer) -row 0 -column 0 -sticky nsew
    grid .analyzerTab.right.box.vsb -row 0 -column 1 -sticky ns
    grid .analyzerTab.right.box.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .analyzerTab.right.box 0 -weight 1
    grid columnconfigure .analyzerTab.right.box 0 -weight 1

    ttk::label .analyzerTab.stats -text "ERROR=0   WARN=0   INFO=0   DEBUG=0   OTHER=0" -padding 6
    pack .analyzerTab.stats -fill x

    bind $ui(anCritical) <<ListboxSelect>> wb::anJumpToCritical
    bind .analyzerTab.top.searchE <Return> {wb::anApplyFilters}
}

proc wb::buildUI {} {
    variable ui

    wm title . "Workbench Integrato"
    wm geometry . 1650x980
    wm minsize . 1280 820
    ttk::style theme use clam

    ttk::frame .toolbar -padding 6
    pack .toolbar -fill x

    ttk::button .toolbar.newExp    -text "Nuovo esperimento" -command wb::newExperiment
    ttk::button .toolbar.saveExp   -text "Salva esperimento" -command wb::saveCurrentExperiment
    ttk::button .toolbar.delExp    -text "Elimina esperimento" -command wb::deleteCurrentExperiment
    ttk::button .toolbar.saveDb    -text "Salva DB" -command wb::saveExperimentsDb
    ttk::button .toolbar.toLaunch  -text "Esperimento -> Launcher" -command wb::useExperimentInLauncher
    ttk::button .toolbar.toResults -text "Esperimento -> Results" -command wb::browseSelectedExperimentOutput
    ttk::button .toolbar.toVal     -text "Esperimento -> Validation" -command wb::loadSelectedExperimentValidation

    pack .toolbar.newExp .toolbar.saveExp .toolbar.delExp .toolbar.saveDb \
         .toolbar.toLaunch .toolbar.toResults .toolbar.toVal -side left -padx 4

    ttk::notebook .nb
    pack .nb -fill both -expand 1

    foreach tab {experimentsTab resultsTab validationTab launcherTab runtimeTab workflowTab analyzerTab} {
        ttk::frame .$tab -padding 4
    }

    .nb add .experimentsTab -text "Experiments"
    .nb add .resultsTab -text "Results"
    .nb add .validationTab -text "Validation"
    .nb add .launcherTab -text "Launcher"
    .nb add .runtimeTab -text "Runtime Log"
    .nb add .workflowTab -text "Workflow"
    .nb add .analyzerTab -text "Log Analyzer"

    wb::buildExperimentsTab
    wb::buildResultsTab
    wb::buildValidationTab
    wb::buildLauncherTab
    wb::buildRuntimeTab
    wb::buildWorkflowTab
    wb::buildAnalyzerTab

    ttk::separator .sep -orient horizontal
    pack .sep -fill x

    ttk::label .status -text "Stato: pronto" -padding 6
    pack .status -fill x

    foreach var {
        wb::launchProfile
        wb::launchConfigPath
        wb::launchCaseName
        wb::launchInputData
        wb::launchOutputRoot
    } {
        trace add variable $var write {apply {{args} {after idle wb::updateLauncherCommandPreview}}}
    }
}

# ==================================================
# MAIN
# ==================================================
wb::buildUI
wb::configureRuntimeLogTags
wb::configureAnalyzerTags
wb::loadExperimentsDb
wb::refreshExperimentsTable
wb::clearExperimentEditor
wb::populateExperimentNotesWidget
wb::loadValidationSampleData
wb::wfLoadSample
wb::updateLauncherCommandPreview
wb::setStatus "workbench integrato pronto"