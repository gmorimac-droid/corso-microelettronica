#!/usr/bin/env wish

package require Tk 8.6

namespace eval wb {
    variable ui

    # -------------------------
    # Experiment Manager state
    # -------------------------
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

    # -------------------------
    # Result Browser state
    # -------------------------
    variable currentRoot ""
    variable selectedPath ""
    variable filterText ""
    variable previewImage ""

    # -------------------------
    # Validation state
    # -------------------------
    variable metricsFile ""
    variable baselineFile ""
    variable metricsData {}
    variable baselineData {}
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

# ==================================================
# EXPERIMENT MANAGER
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
        {
            id EXP003
            name "HDL Smoke Regression"
            domain hdl
            status failed
            description "Prima regression smoke per top_level_dut"
            configPath "configs/tb_smoke.json"
            workflowPath "workflows/hdl_smoke.wflow"
            outputDir "runs/hdl_smoke"
            logPath "runs/hdl_smoke/run.log"
            baselinePath ""
            metricsPath "runs/hdl_smoke/metrics.csv"
            tags "hdl,smoke"
            notes "Failure su checker_mode basic"
            createdAt "2026-03-31 14:05:00"
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

proc wb::saveExperimentsDbAs {} {
    variable experimentsFile
    set f [tk_getSaveFile \
        -title "Salva database esperimenti" \
        -defaultextension ".tcl" \
        -filetypes {{"Tcl database" {.tcl}} {"All files" {*}}}]
    if {$f eq ""} { return }
    set experimentsFile $f
    wb::saveExperimentsDb
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

    if {$filterDomain ne "all" && [dict get $exp domain] ne $filterDomain} {
        return 0
    }
    if {$filterStatus ne "all" && [dict get $exp status] ne $filterStatus} {
        return 0
    }

    set needle [string trim [string tolower $searchText]]
    if {$needle ne ""} {
        set hay [string tolower \
            "[dict get $exp id] [dict get $exp name] [dict get $exp tags] [dict get $exp description]"]
        if {[string first $needle $hay] < 0} {
            return 0
        }
    }
    return 1
}

proc wb::refreshExperimentsTable {} {
    variable ui
    variable experiments

    set tree $ui(expTree)
    foreach item [$tree children {}] {
        $tree delete $item
    }

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

    set ::wb::expId           [dict get $exp id]
    set ::wb::expName         [dict get $exp name]
    set ::wb::expDomain       [dict get $exp domain]
    set ::wb::expStatus       [dict get $exp status]
    set ::wb::expDescription  [dict get $exp description]
    set ::wb::expConfigPath   [dict get $exp configPath]
    set ::wb::expWorkflowPath [dict get $exp workflowPath]
    set ::wb::expOutputDir    [dict get $exp outputDir]
    set ::wb::expLogPath      [dict get $exp logPath]
    set ::wb::expBaselinePath [dict get $exp baselinePath]
    set ::wb::expMetricsPath  [dict get $exp metricsPath]
    set ::wb::expTags         [dict get $exp tags]
    set ::wb::expNotes        [dict get $exp notes]
    set ::wb::expCreatedAt    [dict get $exp createdAt]

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

proc wb::validateExperimentEditor {} {
    if {[string trim $::wb::expName] eq ""} {
        tk_messageBox -icon warning -title "Validazione" \
            -message "Il nome esperimento è obbligatorio."
        return 0
    }
    return 1
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

    if {![wb::validateExperimentEditor]} {
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
        tk_messageBox -icon info -title "Elimina" \
            -message "Seleziona un esperimento da eliminare."
        return
    }

    set ans [tk_messageBox -icon question -type yesno -title "Conferma" \
        -message "Eliminare l'esperimento selezionato?"]
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

proc wb::chooseExperimentConfigPath {} {
    set f [tk_getOpenFile -title "Seleziona config file"]
    if {$f ne ""} { set ::wb::expConfigPath $f }
}

proc wb::chooseExperimentWorkflowPath {} {
    set f [tk_getOpenFile -title "Seleziona workflow file" \
        -filetypes {{"Workflow files" {.wflow}} {"All files" {*}}}]
    if {$f ne ""} { set ::wb::expWorkflowPath $f }
}

proc wb::chooseExperimentOutputDir {} {
    set d [tk_chooseDirectory -title "Seleziona output directory"]
    if {$d ne ""} { set ::wb::expOutputDir $d }
}

proc wb::chooseExperimentLogPath {} {
    set f [tk_getOpenFile -title "Seleziona log file" \
        -filetypes {{"Log files" {.log .txt .out}} {"All files" {*}}}]
    if {$f ne ""} { set ::wb::expLogPath $f }
}

proc wb::chooseExperimentBaselinePath {} {
    set f [tk_getOpenFile -title "Seleziona baseline file"]
    if {$f ne ""} { set ::wb::expBaselinePath $f }
}

proc wb::chooseExperimentMetricsPath {} {
    set f [tk_getOpenFile -title "Seleziona metrics file" \
        -filetypes {{"CSV files" {.csv}} {"All files" {*}}}]
    if {$f ne ""} { set ::wb::expMetricsPath $f }
}

# --------------------------------------------------
# Experiment integration actions
# --------------------------------------------------
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
# RESULT BROWSER
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
    foreach item [$tree children {}] {
        $tree delete $item
    }
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

proc wb::applyResultsFilter {} {
    wb::populateResultsTree
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
# VALIDATION DASHBOARD
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
        if {$line ne ""} {
            lappend lines $line
        }
    }

    if {[llength $lines] < 1} {
        return {}
    }

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

    return [dict create \
        metric $metric \
        value $value \
        baseline $baseline \
        delta $delta \
        min $minVal \
        max $maxVal \
        status $status]
}

proc wb::clearValidationTable {} {
    variable ui
    set tree $ui(valTree)
    foreach item [$tree children {}] {
        $tree delete $item
    }
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

proc wb::clearValidationDetail {} {
    .validationTab.right.detail.metricV configure -text ""
    .validationTab.right.detail.valueV configure -text ""
    .validationTab.right.detail.baseV configure -text ""
    .validationTab.right.detail.deltaV configure -text ""
    .validationTab.right.detail.minV configure -text ""
    .validationTab.right.detail.maxV configure -text ""
    .validationTab.right.detail.statusV configure -text ""
}

proc wb::onValidationTreeSelect {} {
    variable ui
    set tree $ui(valTree)
    set sel [$tree selection]
    if {$sel eq ""} {
        wb::clearValidationDetail
        return
    }

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

    set f [tk_getOpenFile \
        -title "Apri file metriche" \
        -filetypes {{"CSV files" {.csv}} {"All files" {*}}}]
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

    set f [tk_getOpenFile \
        -title "Apri file baseline" \
        -filetypes {{"CSV files" {.csv}} {"All files" {*}}}]
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
    wb::setStatus "sample validation caricata"
}

# ==================================================
# UI BUILD
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

    ttk::label .experimentsTab.right.form.l1 -text "ID:"
    ttk::entry .experimentsTab.right.form.e1 -textvariable wb::expId

    ttk::label .experimentsTab.right.form.l2 -text "Nome:"
    ttk::entry .experimentsTab.right.form.e2 -textvariable wb::expName

    ttk::label .experimentsTab.right.form.l3 -text "Dominio:"
    ttk::combobox .experimentsTab.right.form.c3 -state readonly \
        -values {radar satellite underwater hdl} \
        -textvariable wb::expDomain

    ttk::label .experimentsTab.right.form.l4 -text "Stato:"
    ttk::combobox .experimentsTab.right.form.c4 -state readonly \
        -values {draft ready running completed validated failed archived} \
        -textvariable wb::expStatus

    ttk::label .experimentsTab.right.form.l5 -text "Descrizione:"
    ttk::entry .experimentsTab.right.form.e5 -textvariable wb::expDescription

    ttk::label .experimentsTab.right.form.l6 -text "Config path:"
    ttk::entry .experimentsTab.right.form.e6 -textvariable wb::expConfigPath
    ttk::button .experimentsTab.right.form.b6 -text "..." -width 3 -command wb::chooseExperimentConfigPath

    ttk::label .experimentsTab.right.form.l7 -text "Workflow path:"
    ttk::entry .experimentsTab.right.form.e7 -textvariable wb::expWorkflowPath
    ttk::button .experimentsTab.right.form.b7 -text "..." -width 3 -command wb::chooseExperimentWorkflowPath

    ttk::label .experimentsTab.right.form.l8 -text "Output dir:"
    ttk::entry .experimentsTab.right.form.e8 -textvariable wb::expOutputDir
    ttk::button .experimentsTab.right.form.b8 -text "..." -width 3 -command wb::chooseExperimentOutputDir

    ttk::label .experimentsTab.right.form.l9 -text "Log path:"
    ttk::entry .experimentsTab.right.form.e9 -textvariable wb::expLogPath
    ttk::button .experimentsTab.right.form.b9 -text "..." -width 3 -command wb::chooseExperimentLogPath

    ttk::label .experimentsTab.right.form.l10 -text "Baseline path:"
    ttk::entry .experimentsTab.right.form.e10 -textvariable wb::expBaselinePath
    ttk::button .experimentsTab.right.form.b10 -text "..." -width 3 -command wb::chooseExperimentBaselinePath

    ttk::label .experimentsTab.right.form.l11 -text "Metrics path:"
    ttk::entry .experimentsTab.right.form.e11 -textvariable wb::expMetricsPath
    ttk::button .experimentsTab.right.form.b11 -text "..." -width 3 -command wb::chooseExperimentMetricsPath

    ttk::label .experimentsTab.right.form.l12 -text "Tags:"
    ttk::entry .experimentsTab.right.form.e12 -textvariable wb::expTags

    ttk::label .experimentsTab.right.form.l13 -text "Creato:"
    ttk::entry .experimentsTab.right.form.e13 -textvariable wb::expCreatedAt

    ttk::label .experimentsTab.right.form.l14 -text "Note:"
    text .experimentsTab.right.form.tnotes -height 7 -width 30 -wrap word

    grid .experimentsTab.right.form.l1  -row 0  -column 0 -sticky w -pady 4
    grid .experimentsTab.right.form.e1  -row 0  -column 1 -columnspan 2 -sticky ew -pady 4
    grid .experimentsTab.right.form.l2  -row 1  -column 0 -sticky w -pady 4
    grid .experimentsTab.right.form.e2  -row 1  -column 1 -columnspan 2 -sticky ew -pady 4
    grid .experimentsTab.right.form.l3  -row 2  -column 0 -sticky w -pady 4
    grid .experimentsTab.right.form.c3  -row 2  -column 1 -columnspan 2 -sticky ew -pady 4
    grid .experimentsTab.right.form.l4  -row 3  -column 0 -sticky w -pady 4
    grid .experimentsTab.right.form.c4  -row 3  -column 1 -columnspan 2 -sticky ew -pady 4
    grid .experimentsTab.right.form.l5  -row 4  -column 0 -sticky w -pady 4
    grid .experimentsTab.right.form.e5  -row 4  -column 1 -columnspan 2 -sticky ew -pady 4
    grid .experimentsTab.right.form.l6  -row 5  -column 0 -sticky w -pady 4
    grid .experimentsTab.right.form.e6  -row 5  -column 1 -sticky ew -pady 4
    grid .experimentsTab.right.form.b6  -row 5  -column 2 -sticky ew -padx 4
    grid .experimentsTab.right.form.l7  -row 6  -column 0 -sticky w -pady 4
    grid .experimentsTab.right.form.e7  -row 6  -column 1 -sticky ew -pady 4
    grid .experimentsTab.right.form.b7  -row 6  -column 2 -sticky ew -padx 4
    grid .experimentsTab.right.form.l8  -row 7  -column 0 -sticky w -pady 4
    grid .experimentsTab.right.form.e8  -row 7  -column 1 -sticky ew -pady 4
    grid .experimentsTab.right.form.b8  -row 7  -column 2 -sticky ew -padx 4
    grid .experimentsTab.right.form.l9  -row 8  -column 0 -sticky w -pady 4
    grid .experimentsTab.right.form.e9  -row 8  -column 1 -sticky ew -pady 4
    grid .experimentsTab.right.form.b9  -row 8  -column 2 -sticky ew -padx 4
    grid .experimentsTab.right.form.l10 -row 9  -column 0 -sticky w -pady 4
    grid .experimentsTab.right.form.e10 -row 9  -column 1 -sticky ew -pady 4
    grid .experimentsTab.right.form.b10 -row 9  -column 2 -sticky ew -padx 4
    grid .experimentsTab.right.form.l11 -row 10 -column 0 -sticky w -pady 4
    grid .experimentsTab.right.form.e11 -row 10 -column 1 -sticky ew -pady 4
    grid .experimentsTab.right.form.b11 -row 10 -column 2 -sticky ew -padx 4
    grid .experimentsTab.right.form.l12 -row 11 -column 0 -sticky w -pady 4
    grid .experimentsTab.right.form.e12 -row 11 -column 1 -columnspan 2 -sticky ew -pady 4
    grid .experimentsTab.right.form.l13 -row 12 -column 0 -sticky w -pady 4
    grid .experimentsTab.right.form.e13 -row 12 -column 1 -columnspan 2 -sticky ew -pady 4
    grid .experimentsTab.right.form.l14 -row 13 -column 0 -sticky nw -pady 4
    grid .experimentsTab.right.form.tnotes -row 13 -column 1 -columnspan 2 -sticky ew -pady 4

    ttk::labelframe .experimentsTab.right.actions -text "Azioni rapide" -padding 10
    pack .experimentsTab.right.actions -fill x -pady 10

    ttk::button .experimentsTab.right.actions.bc -text "Apri config" -command {wb::openPath $::wb::expConfigPath}
    ttk::button .experimentsTab.right.actions.bw -text "Apri workflow" -command {wb::openPath $::wb::expWorkflowPath}
    ttk::button .experimentsTab.right.actions.bo -text "Apri output" -command {wb::openPath $::wb::expOutputDir}
    ttk::button .experimentsTab.right.actions.bl -text "Apri log" -command {wb::openPath $::wb::expLogPath}
    ttk::button .experimentsTab.right.actions.bb -text "Apri baseline" -command {wb::openPath $::wb::expBaselinePath}
    ttk::button .experimentsTab.right.actions.br -text "Vai a Results" -command wb::browseSelectedExperimentOutput
    ttk::button .experimentsTab.right.actions.bv -text "Vai a Validation" -command wb::loadSelectedExperimentValidation

    pack .experimentsTab.right.actions.bc .experimentsTab.right.actions.bw \
         .experimentsTab.right.actions.bo .experimentsTab.right.actions.bl \
         .experimentsTab.right.actions.bb .experimentsTab.right.actions.br \
         .experimentsTab.right.actions.bv -fill x -pady 2
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
    ttk::button .resultsTab.top.filterBtn -text "Applica filtro" -command wb::applyResultsFilter

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

    set ui(resTree) [ttk::treeview .resultsTab.left.box.tree \
        -columns {path kind} -show tree -selectmode browse]
    ttk::scrollbar .resultsTab.left.box.vsb -orient vertical -command "$ui(resTree) yview"
    ttk::scrollbar .resultsTab.left.box.hsb -orient horizontal -command "$ui(resTree) xview"
    $ui(resTree) configure -yscrollcommand ".resultsTab.left.box.vsb set" -xscrollcommand ".resultsTab.left.box.hsb set"

    grid $ui(resTree) -row 0 -column 0 -sticky nsew
    grid .resultsTab.left.box.vsb -row 0 -column 1 -sticky ns
    grid .resultsTab.left.box.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .resultsTab.left.box 0 -weight 1
    grid columnconfigure .resultsTab.left.box 0 -weight 1

    bind $ui(resTree) <<TreeviewSelect>> wb::onResultsTreeSelect
    bind .resultsTab.top.filterEntry <Return> {wb::applyResultsFilter}

    ttk::labelframe .resultsTab.right.info -text "Info file" -padding 10
    pack .resultsTab.right.info -fill x

    grid columnconfigure .resultsTab.right.info 1 -weight 1

    ttk::label .resultsTab.right.info.l1 -text "Path:"
    ttk::label .resultsTab.right.info.v1 -text "" -wraplength 700 -justify left
    ttk::label .resultsTab.right.info.l2 -text "Tipo:"
    ttk::label .resultsTab.right.info.v2 -text ""
    ttk::label .resultsTab.right.info.l3 -text "Dimensione:"
    ttk::label .resultsTab.right.info.v3 -text ""
    ttk::label .resultsTab.right.info.l4 -text "Modifica:"
    ttk::label .resultsTab.right.info.v4 -text ""

    grid .resultsTab.right.info.l1 -row 0 -column 0 -sticky nw -pady 3
    grid .resultsTab.right.info.v1 -row 0 -column 1 -sticky w -pady 3
    grid .resultsTab.right.info.l2 -row 1 -column 0 -sticky w -pady 3
    grid .resultsTab.right.info.v2 -row 1 -column 1 -sticky w -pady 3
    grid .resultsTab.right.info.l3 -row 2 -column 0 -sticky w -pady 3
    grid .resultsTab.right.info.v3 -row 2 -column 1 -sticky w -pady 3
    grid .resultsTab.right.info.l4 -row 3 -column 0 -sticky w -pady 3
    grid .resultsTab.right.info.v4 -row 3 -column 1 -sticky w -pady 3

    set ui(resInfoPath)  .resultsTab.right.info.v1
    set ui(resInfoType)  .resultsTab.right.info.v2
    set ui(resInfoSize)  .resultsTab.right.info.v3
    set ui(resInfoMtime) .resultsTab.right.info.v4

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
    $ui(resTextPreview) configure -yscrollcommand ".resultsTab.right.preview.textTab.vsb set" \
        -xscrollcommand ".resultsTab.right.preview.textTab.hsb set"

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
        -columns {metric value baseline delta min max status} \
        -show headings -selectmode browse]

    foreach {col txt w} {
        metric   "Metric"    180
        value    "Value"     100
        baseline "Baseline"  100
        delta    "Delta"     100
        min      "Min"       80
        max      "Max"       80
        status   "Status"    90
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
        0 "Metric:"   metricV
        1 "Value:"    valueV
        2 "Baseline:" baseV
        3 "Delta:"    deltaV
        4 "Min:"      minV
        5 "Max:"      maxV
        6 "Status:"   statusV
    } {
        ttk::label .validationTab.right.detail.l$row -text $lbl
        ttk::label .validationTab.right.detail.$var -text "" -wraplength 320 -justify left
        grid .validationTab.right.detail.l$row -row $row -column 0 -sticky w -pady 4
        grid .validationTab.right.detail.$var -row $row -column 1 -sticky w -pady 4
    }

    ttk::labelframe .validationTab.right.help -text "Regole V1" -padding 10
    pack .validationTab.right.help -fill x -pady 10

    ttk::label .validationTab.right.help.txt -justify left -text \
"Status:
- PASS: value dentro [min,max]
- FAIL: value fuori soglia
- WARN: soglie mancanti

Delta:
- value - baseline

Formato metriche:
metric,value,min,max

Formato baseline:
metric,value"

    pack .validationTab.right.help.txt -anchor w

    set ui(valSummary) [ttk::label .validationTab.summary -text "PASS=0   WARN=0   FAIL=0   =>   PASS" -padding 6]
    pack .validationTab.summary -fill x
}

proc wb::buildUI {} {
    wm title . "Workbench - Secondo Blocco"
    wm geometry . 1550x950
    wm minsize . 1220 780
    ttk::style theme use clam

    ttk::frame .toolbar -padding 6
    pack .toolbar -fill x

    ttk::button .toolbar.newExp    -text "Nuovo esperimento" -command wb::newExperiment
    ttk::button .toolbar.saveExp   -text "Salva esperimento" -command wb::saveCurrentExperiment
    ttk::button .toolbar.delExp    -text "Elimina esperimento" -command wb::deleteCurrentExperiment
    ttk::button .toolbar.saveDb    -text "Salva DB" -command wb::saveExperimentsDb
    ttk::button .toolbar.saveDbAs  -text "Salva DB come" -command wb::saveExperimentsDbAs
    ttk::button .toolbar.goResults -text "Vai a Results" -command wb::browseSelectedExperimentOutput
    ttk::button .toolbar.goVal     -text "Vai a Validation" -command wb::loadSelectedExperimentValidation

    pack .toolbar.newExp .toolbar.saveExp .toolbar.delExp \
         .toolbar.saveDb .toolbar.saveDbAs .toolbar.goResults .toolbar.goVal \
         -side left -padx 4

    ttk::notebook .nb
    pack .nb -fill both -expand 1

    ttk::frame .experimentsTab -padding 4
    ttk::frame .resultsTab -padding 4
    ttk::frame .validationTab -padding 4

    .nb add .experimentsTab -text "Experiments"
    .nb add .resultsTab -text "Results"
    .nb add .validationTab -text "Validation"

    wb::buildExperimentsTab
    wb::buildResultsTab
    wb::buildValidationTab

    ttk::separator .sep -orient horizontal
    pack .sep -fill x

    ttk::label .status -text "Stato: pronto" -padding 6
    pack .status -fill x
}

# ==================================================
# MAIN
# ==================================================
wb::buildUI
wb::loadExperimentsDb
wb::refreshExperimentsTable
wb::clearExperimentEditor
wb::populateExperimentNotesWidget
wb::loadValidationSampleData
wb::setStatus "pronto"