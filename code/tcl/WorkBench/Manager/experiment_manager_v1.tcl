#!/usr/bin/env wish

package require Tk 8.6

namespace eval em {
    variable experiments {}
    variable currentFile "experiments_db.tcl"
    variable selectedIndex -1

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
    variable expTags ""
    variable expNotes ""
    variable expCreatedAt ""

    variable ui
}

# --------------------------------------------------
# Utility
# --------------------------------------------------
proc em::logStatus {msg} {
    .status configure -text "Stato: $msg"
}

proc em::openPath {path} {
    if {$path eq ""} {
        return
    }
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

proc em::nowString {} {
    return [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
}

proc em::nextExperimentId {} {
    variable experiments
    set maxNum 0
    foreach exp $experiments {
        if {[dict exists $exp id]} {
            set id [dict get $exp id]
            if {[regexp {^EXP([0-9]+)$} $id -> num]} {
                if {$num > $maxNum} {
                    set maxNum $num
                }
            }
        }
    }
    incr maxNum
    return [format "EXP%03d" $maxNum]
}

proc em::clearEditor {} {
    set ::em::expId ""
    set ::em::expName ""
    set ::em::expDomain "radar"
    set ::em::expStatus "draft"
    set ::em::expDescription ""
    set ::em::expConfigPath ""
    set ::em::expWorkflowPath ""
    set ::em::expOutputDir ""
    set ::em::expLogPath ""
    set ::em::expBaselinePath ""
    set ::em::expTags ""
    set ::em::expNotes ""
    set ::em::expCreatedAt ""
}

proc em::populateNotesWidget {} {
    if {[winfo exists .right.form.tnotes]} {
        .right.form.tnotes delete 1.0 end
        .right.form.tnotes insert end $::em::expNotes
    }
}

proc em::readNotesWidget {} {
    if {[winfo exists .right.form.tnotes]} {
        set ::em::expNotes [string trim [.right.form.tnotes get 1.0 end]]
    }
}

# --------------------------------------------------
# Data handling
# --------------------------------------------------
proc em::defaultExperiments {} {
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
            baselinePath ""
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
            tags "hdl,smoke"
            notes "Failure su checker_mode basic"
            createdAt "2026-03-31 14:05:00"
        }
    }
}

proc em::loadDatabase {} {
    variable currentFile
    variable experiments

    if {[file exists $currentFile]} {
        if {[catch {
            set f [open $currentFile r]
            set data [read $f]
            close $f
            set experiments $data
        } err]} {
            set experiments [em::defaultExperiments]
            em::logStatus "errore caricamento db"
            return
        }
        em::logStatus "database caricato"
    } else {
        set experiments [em::defaultExperiments]
        em::logStatus "database inizializzato"
    }
}

proc em::saveDatabase {} {
    variable currentFile
    variable experiments

    if {[catch {
        set f [open $currentFile w]
        puts $f $experiments
        close $f
    } err]} {
        tk_messageBox -icon error -title "Errore" \
            -message "Impossibile salvare il database:\n$err"
        return
    }

    em::logStatus "database salvato"
}

proc em::saveDatabaseAs {} {
    variable currentFile
    set f [tk_getSaveFile \
        -title "Salva database esperimenti" \
        -defaultextension ".tcl" \
        -filetypes {{"Tcl database" {.tcl}} {"All files" {*}}}]
    if {$f eq ""} { return }
    set currentFile $f
    em::saveDatabase
}

# --------------------------------------------------
# Filtering / table
# --------------------------------------------------
proc em::matchesFilters {exp} {
    variable filterDomain
    variable filterStatus
    variable searchText

    if {$filterDomain ne "all"} {
        if {[dict get $exp domain] ne $filterDomain} {
            return 0
        }
    }

    if {$filterStatus ne "all"} {
        if {[dict get $exp status] ne $filterStatus} {
            return 0
        }
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

proc em::refreshTable {} {
    variable ui
    variable experiments

    set tree $ui(tree)
    foreach item [$tree children {}] {
        $tree delete $item
    }

    set idx 0
    foreach exp $experiments {
        if {![em::matchesFilters $exp]} {
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

    em::logStatus "tabella aggiornata"
}

# --------------------------------------------------
# Selection / editor
# --------------------------------------------------
proc em::loadExperimentIntoEditor {index} {
    variable experiments
    variable selectedIndex

    if {$index < 0 || $index >= [llength $experiments]} {
        return
    }

    set selectedIndex $index
    set exp [lindex $experiments $index]

    set ::em::expId           [dict get $exp id]
    set ::em::expName         [dict get $exp name]
    set ::em::expDomain       [dict get $exp domain]
    set ::em::expStatus       [dict get $exp status]
    set ::em::expDescription  [dict get $exp description]
    set ::em::expConfigPath   [dict get $exp configPath]
    set ::em::expWorkflowPath [dict get $exp workflowPath]
    set ::em::expOutputDir    [dict get $exp outputDir]
    set ::em::expLogPath      [dict get $exp logPath]
    set ::em::expBaselinePath [dict get $exp baselinePath]
    set ::em::expTags         [dict get $exp tags]
    set ::em::expNotes        [dict get $exp notes]
    set ::em::expCreatedAt    [dict get $exp createdAt]

    em::populateNotesWidget
    em::logStatus "esperimento selezionato"
}

proc em::onTreeSelect {} {
    variable ui
    set tree $ui(tree)
    set sel [$tree selection]
    if {$sel eq ""} { return }

    set item [lindex $sel 0]
    set index [$tree set $item 0]
    em::loadExperimentIntoEditor $index
}

proc em::buildExperimentDictFromEditor {} {
    em::readNotesWidget

    if {[string trim $::em::expId] eq ""} {
        set ::em::expId [em::nextExperimentId]
    }
    if {[string trim $::em::expCreatedAt] eq ""} {
        set ::em::expCreatedAt [em::nowString]
    }

    return [dict create \
        id           $::em::expId \
        name         $::em::expName \
        domain       $::em::expDomain \
        status       $::em::expStatus \
        description  $::em::expDescription \
        configPath   $::em::expConfigPath \
        workflowPath $::em::expWorkflowPath \
        outputDir    $::em::expOutputDir \
        logPath      $::em::expLogPath \
        baselinePath $::em::expBaselinePath \
        tags         $::em::expTags \
        notes        $::em::expNotes \
        createdAt    $::em::expCreatedAt]
}

proc em::validateEditor {} {
    if {[string trim $::em::expName] eq ""} {
        tk_messageBox -icon warning -title "Validazione" \
            -message "Il nome esperimento è obbligatorio."
        return 0
    }
    return 1
}

# --------------------------------------------------
# CRUD
# --------------------------------------------------
proc em::newExperiment {} {
    variable selectedIndex
    set selectedIndex -1
    em::clearEditor
    set ::em::expId [em::nextExperimentId]
    set ::em::expCreatedAt [em::nowString]
    em::populateNotesWidget
    em::logStatus "nuovo esperimento"
}

proc em::saveCurrentExperiment {} {
    variable experiments
    variable selectedIndex

    if {![em::validateEditor]} {
        return
    }

    set exp [em::buildExperimentDictFromEditor]

    if {$selectedIndex < 0} {
        lappend experiments $exp
        set selectedIndex [expr {[llength $experiments] - 1}]
        em::logStatus "esperimento creato"
    } else {
        set newList {}
        set i 0
        foreach old $experiments {
            if {$i == $selectedIndex} {
                lappend newList $exp
            } else {
                lappend newList $old
            }
            incr i
        }
        set experiments $newList
        em::logStatus "esperimento aggiornato"
    }

    em::refreshTable
}

proc em::deleteCurrentExperiment {} {
    variable experiments
    variable selectedIndex

    if {$selectedIndex < 0} {
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
        if {$i != $selectedIndex} {
            lappend newList $exp
        }
        incr i
    }
    set experiments $newList
    set selectedIndex -1
    em::clearEditor
    em::populateNotesWidget
    em::refreshTable
    em::logStatus "esperimento eliminato"
}

# --------------------------------------------------
# Path helpers
# --------------------------------------------------
proc em::chooseConfigPath {} {
    set f [tk_getOpenFile -title "Seleziona config file"]
    if {$f ne ""} {
        set ::em::expConfigPath $f
    }
}

proc em::chooseWorkflowPath {} {
    set f [tk_getOpenFile -title "Seleziona workflow file" \
        -filetypes {{"Workflow files" {.wflow}} {"All files" {*}}}]
    if {$f ne ""} {
        set ::em::expWorkflowPath $f
    }
}

proc em::chooseOutputDir {} {
    set d [tk_chooseDirectory -title "Seleziona output directory"]
    if {$d ne ""} {
        set ::em::expOutputDir $d
    }
}

proc em::chooseLogPath {} {
    set f [tk_getOpenFile -title "Seleziona log file" \
        -filetypes {{"Log files" {.log .txt .out}} {"All files" {*}}}]
    if {$f ne ""} {
        set ::em::expLogPath $f
    }
}

proc em::chooseBaselinePath {} {
    set f [tk_getOpenFile -title "Seleziona baseline file"]
    if {$f ne ""} {
        set ::em::expBaselinePath $f
    }
}

# --------------------------------------------------
# Sample
# --------------------------------------------------
proc em::loadSampleDb {} {
    variable experiments
    set experiments [em::defaultExperiments]
    set ::em::selectedIndex -1
    em::clearEditor
    em::populateNotesWidget
    em::refreshTable
    em::logStatus "sample db caricato"
}

# --------------------------------------------------
# UI
# --------------------------------------------------
proc em::buildUI {} {
    variable ui

    wm title . "Experiment Manager"
    wm geometry . 1450x900
    wm minsize . 1180 760
    ttk::style theme use clam

    ttk::frame .toolbar -padding 6
    pack .toolbar -fill x

    ttk::button .toolbar.new    -text "Nuovo" -command em::newExperiment
    ttk::button .toolbar.save   -text "Salva esperimento" -command em::saveCurrentExperiment
    ttk::button .toolbar.del    -text "Elimina" -command em::deleteCurrentExperiment
    ttk::button .toolbar.dbsave -text "Salva DB" -command em::saveDatabase
    ttk::button .toolbar.dbas   -text "Salva DB come" -command em::saveDatabaseAs
    ttk::button .toolbar.sample -text "Sample DB" -command em::loadSampleDb

    pack .toolbar.new .toolbar.save .toolbar.del .toolbar.dbsave .toolbar.dbas .toolbar.sample \
        -side left -padx 4

    ttk::frame .filters -padding 6
    pack .filters -fill x

    ttk::label .filters.dl -text "Dominio:"
    ttk::combobox .filters.dc -state readonly \
        -values {all radar satellite underwater hdl} \
        -textvariable em::filterDomain

    ttk::label .filters.sl -text "Stato:"
    ttk::combobox .filters.sc -state readonly \
        -values {all draft ready running completed validated failed archived} \
        -textvariable em::filterStatus

    ttk::label .filters.ql -text "Cerca:"
    ttk::entry .filters.qe -textvariable em::searchText
    ttk::button .filters.apply -text "Applica filtri" -command em::refreshTable

    pack .filters.apply -side right -padx 3
    pack .filters.qe -side right -padx 3
    pack .filters.ql -side right -padx 3
    pack .filters.sc -side right -padx 3
    pack .filters.sl -side right -padx 3
    pack .filters.dc -side right -padx 3
    pack .filters.dl -side right -padx 3

    ttk::panedwindow .pw -orient horizontal
    pack .pw -fill both -expand 1

    ttk::frame .left -padding 6
    ttk::frame .right -padding 6
    .pw add .left -weight 3
    .pw add .right -weight 2

    # Left: table
    ttk::labelframe .left.box -text "Esperimenti" -padding 6
    pack .left.box -fill both -expand 1

    set ui(tree) [ttk::treeview .left.box.tree \
        -columns {idx id name domain status createdAt} -show headings -selectmode browse]

    foreach {col txt w} {
        idx "#" 50
        id "ID" 90
        name "Nome" 280
        domain "Dominio" 110
        status "Stato" 110
        createdAt "Creato" 150
    } {
        $ui(tree) heading $col -text $txt
        $ui(tree) column $col -width $w
    }

    ttk::scrollbar .left.box.vsb -orient vertical -command "$ui(tree) yview"
    ttk::scrollbar .left.box.hsb -orient horizontal -command "$ui(tree) xview"
    $ui(tree) configure -yscrollcommand ".left.box.vsb set" -xscrollcommand ".left.box.hsb set"

    grid $ui(tree) -row 0 -column 0 -sticky nsew
    grid .left.box.vsb -row 0 -column 1 -sticky ns
    grid .left.box.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .left.box 0 -weight 1
    grid columnconfigure .left.box 0 -weight 1

    bind $ui(tree) <<TreeviewSelect>> em::onTreeSelect
    bind .filters.qe <Return> {em::refreshTable}

    # Right: editor form
    ttk::labelframe .right.form -text "Dettagli esperimento" -padding 10
    pack .right.form -fill both -expand 1

    grid columnconfigure .right.form 1 -weight 1

    ttk::label .right.form.l1 -text "ID:"
    ttk::entry .right.form.e1 -textvariable em::expId

    ttk::label .right.form.l2 -text "Nome:"
    ttk::entry .right.form.e2 -textvariable em::expName

    ttk::label .right.form.l3 -text "Dominio:"
    ttk::combobox .right.form.c3 -state readonly \
        -values {radar satellite underwater hdl} \
        -textvariable em::expDomain

    ttk::label .right.form.l4 -text "Stato:"
    ttk::combobox .right.form.c4 -state readonly \
        -values {draft ready running completed validated failed archived} \
        -textvariable em::expStatus

    ttk::label .right.form.l5 -text "Descrizione:"
    ttk::entry .right.form.e5 -textvariable em::expDescription

    ttk::label .right.form.l6 -text "Config path:"
    ttk::entry .right.form.e6 -textvariable em::expConfigPath
    ttk::button .right.form.b6 -text "..." -width 3 -command em::chooseConfigPath

    ttk::label .right.form.l7 -text "Workflow path:"
    ttk::entry .right.form.e7 -textvariable em::expWorkflowPath
    ttk::button .right.form.b7 -text "..." -width 3 -command em::chooseWorkflowPath

    ttk::label .right.form.l8 -text "Output dir:"
    ttk::entry .right.form.e8 -textvariable em::expOutputDir
    ttk::button .right.form.b8 -text "..." -width 3 -command em::chooseOutputDir

    ttk::label .right.form.l9 -text "Log path:"
    ttk::entry .right.form.e9 -textvariable em::expLogPath
    ttk::button .right.form.b9 -text "..." -width 3 -command em::chooseLogPath

    ttk::label .right.form.l10 -text "Baseline path:"
    ttk::entry .right.form.e10 -textvariable em::expBaselinePath
    ttk::button .right.form.b10 -text "..." -width 3 -command em::chooseBaselinePath

    ttk::label .right.form.l11 -text "Tags:"
    ttk::entry .right.form.e11 -textvariable em::expTags

    ttk::label .right.form.l12 -text "Creato:"
    ttk::entry .right.form.e12 -textvariable em::expCreatedAt

    ttk::label .right.form.l13 -text "Note:"
    text .right.form.tnotes -height 8 -width 30 -wrap word

    grid .right.form.l1  -row 0  -column 0 -sticky w -pady 4
    grid .right.form.e1  -row 0  -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.form.l2  -row 1  -column 0 -sticky w -pady 4
    grid .right.form.e2  -row 1  -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.form.l3  -row 2  -column 0 -sticky w -pady 4
    grid .right.form.c3  -row 2  -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.form.l4  -row 3  -column 0 -sticky w -pady 4
    grid .right.form.c4  -row 3  -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.form.l5  -row 4  -column 0 -sticky w -pady 4
    grid .right.form.e5  -row 4  -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.form.l6  -row 5  -column 0 -sticky w -pady 4
    grid .right.form.e6  -row 5  -column 1 -sticky ew -pady 4
    grid .right.form.b6  -row 5  -column 2 -sticky ew -padx 4

    grid .right.form.l7  -row 6  -column 0 -sticky w -pady 4
    grid .right.form.e7  -row 6  -column 1 -sticky ew -pady 4
    grid .right.form.b7  -row 6  -column 2 -sticky ew -padx 4

    grid .right.form.l8  -row 7  -column 0 -sticky w -pady 4
    grid .right.form.e8  -row 7  -column 1 -sticky ew -pady 4
    grid .right.form.b8  -row 7  -column 2 -sticky ew -padx 4

    grid .right.form.l9  -row 8  -column 0 -sticky w -pady 4
    grid .right.form.e9  -row 8  -column 1 -sticky ew -pady 4
    grid .right.form.b9  -row 8  -column 2 -sticky ew -padx 4

    grid .right.form.l10 -row 9  -column 0 -sticky w -pady 4
    grid .right.form.e10 -row 9  -column 1 -sticky ew -pady 4
    grid .right.form.b10 -row 9  -column 2 -sticky ew -padx 4

    grid .right.form.l11 -row 10 -column 0 -sticky w -pady 4
    grid .right.form.e11 -row 10 -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.form.l12 -row 11 -column 0 -sticky w -pady 4
    grid .right.form.e12 -row 11 -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.form.l13 -row 12 -column 0 -sticky nw -pady 4
    grid .right.form.tnotes -row 12 -column 1 -columnspan 2 -sticky ew -pady 4

    ttk::labelframe .right.actions -text "Azioni rapide" -padding 10
    pack .right.actions -fill x -pady 10

    ttk::button .right.actions.bc -text "Apri config" -command {em::openPath $::em::expConfigPath}
    ttk::button .right.actions.bw -text "Apri workflow" -command {em::openPath $::em::expWorkflowPath}
    ttk::button .right.actions.bo -text "Apri output" -command {em::openPath $::em::expOutputDir}
    ttk::button .right.actions.bl -text "Apri log" -command {em::openPath $::em::expLogPath}
    ttk::button .right.actions.bb -text "Apri baseline" -command {em::openPath $::em::expBaselinePath}

    pack .right.actions.bc .right.actions.bw .right.actions.bo .right.actions.bl .right.actions.bb \
        -fill x -pady 2

    ttk::separator .sep -orient horizontal
    pack .sep -fill x

    ttk::label .status -text "Stato: pronto" -padding 6
    pack .status -fill x
}

# --------------------------------------------------
# Main
# --------------------------------------------------
em::buildUI
em::loadDatabase
em::refreshTable
em::clearEditor
em::populateNotesWidget
em::logStatus "pronto"