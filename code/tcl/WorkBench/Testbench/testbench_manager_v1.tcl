#!/usr/bin/env wish

package require Tk 8.6

namespace eval tb {
    variable tests {}
    variable dbFile "testbench_db.tcl"
    variable selectedIndex -1

    variable filterDomain "all"
    variable filterSuite "all"
    variable filterStatus "all"
    variable searchText ""

    variable tcId ""
    variable tcName ""
    variable tcSuite "default"
    variable tcDomain "radar"
    variable tcPriority "medium"
    variable tcExpectedStatus "pass"
    variable tcLastStatus "draft"
    variable tcDescription ""
    variable tcConfigPath ""
    variable tcWorkflowPath ""
    variable tcOutputDir ""
    variable tcLogPath ""
    variable tcMetricsPath ""
    variable tcTags ""
    variable tcNotes ""
    variable tcCreatedAt ""

    variable ui
}

# --------------------------------------------------
# Utility
# --------------------------------------------------
proc tb::setStatus {msg} {
    .status configure -text "Stato: $msg"
}

proc tb::openPath {path} {
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

proc tb::nowString {} {
    return [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
}

proc tb::nextTestId {} {
    variable tests
    set maxNum 0
    foreach t $tests {
        if {[dict exists $t id]} {
            set id [dict get $t id]
            if {[regexp {^TC([0-9]+)$} $id -> num]} {
                if {$num > $maxNum} { set maxNum $num }
            }
        }
    }
    incr maxNum
    return [format "TC%03d" $maxNum]
}

proc tb::clearEditor {} {
    set ::tb::tcId ""
    set ::tb::tcName ""
    set ::tb::tcSuite "default"
    set ::tb::tcDomain "radar"
    set ::tb::tcPriority "medium"
    set ::tb::tcExpectedStatus "pass"
    set ::tb::tcLastStatus "draft"
    set ::tb::tcDescription ""
    set ::tb::tcConfigPath ""
    set ::tb::tcWorkflowPath ""
    set ::tb::tcOutputDir ""
    set ::tb::tcLogPath ""
    set ::tb::tcMetricsPath ""
    set ::tb::tcTags ""
    set ::tb::tcNotes ""
    set ::tb::tcCreatedAt ""
    if {[winfo exists .right.form.tnotes]} {
        .right.form.tnotes delete 1.0 end
    }
}

proc tb::populateNotesWidget {} {
    if {[winfo exists .right.form.tnotes]} {
        .right.form.tnotes delete 1.0 end
        .right.form.tnotes insert end $::tb::tcNotes
    }
}

proc tb::readNotesWidget {} {
    if {[winfo exists .right.form.tnotes]} {
        set ::tb::tcNotes [string trim [.right.form.tnotes get 1.0 end]]
    }
}

# --------------------------------------------------
# Sample DB
# --------------------------------------------------
proc tb::defaultTests {} {
    return {
        {
            id TC001
            name "Radar nominal detect-track"
            suite "radar_smoke"
            domain radar
            priority high
            expectedStatus pass
            lastStatus passed
            description "Caso nominale radar con detect e track"
            configPath "configs/radar_nominal.json"
            workflowPath "workflows/radar_smoke.wflow"
            outputDir "runs/radar_nominal"
            logPath "runs/radar_nominal/run.log"
            metricsPath "runs/radar_nominal/metrics.csv"
            tags "radar,smoke,nominal"
            notes "Baseline per regression quick"
            createdAt "2026-03-31 10:10:00"
        }
        {
            id TC002
            name "Satellite low elevation edge"
            suite "sat_visibility"
            domain satellite
            priority medium
            expectedStatus manual
            lastStatus ready
            description "Caso limite su elevazione minima"
            configPath "configs/sat_edge.json"
            workflowPath "workflows/sat_visibility.wflow"
            outputDir "runs/sat_edge"
            logPath ""
            metricsPath ""
            tags "satellite,edge,visibility"
            notes "Richiede analisi manuale finestre"
            createdAt "2026-03-31 11:25:00"
        }
        {
            id TC003
            name "HDL smoke reset sequence"
            suite "hdl_smoke"
            domain hdl
            priority high
            expectedStatus pass
            lastStatus failed
            description "Smoke test reset + interfaccia base"
            configPath "configs/tb_reset_smoke.json"
            workflowPath "workflows/hdl_smoke.wflow"
            outputDir "runs/hdl_reset"
            logPath "runs/hdl_reset/run.log"
            metricsPath "runs/hdl_reset/metrics.csv"
            tags "hdl,reset,smoke"
            notes "Failure su checker reset_done"
            createdAt "2026-03-31 14:20:00"
        }
    }
}

# --------------------------------------------------
# Persistence
# --------------------------------------------------
proc tb::loadDb {} {
    variable dbFile
    variable tests

    if {[file exists $dbFile]} {
        if {[catch {
            set f [open $dbFile r]
            set tests [read $f]
            close $f
        } err]} {
            set tests [tb::defaultTests]
            tb::setStatus "errore caricamento db"
            return
        }
    } else {
        set tests [tb::defaultTests]
    }
    tb::setStatus "database testbench caricato"
}

proc tb::saveDb {} {
    variable dbFile
    variable tests

    if {[catch {
        set f [open $dbFile w]
        puts $f $tests
        close $f
    } err]} {
        tk_messageBox -icon error -title "Errore" \
            -message "Impossibile salvare il database:\n$err"
        return
    }

    tb::setStatus "database salvato"
}

proc tb::saveDbAs {} {
    variable dbFile
    set f [tk_getSaveFile \
        -title "Salva database testbench" \
        -defaultextension ".tcl" \
        -filetypes {{"Tcl database" {.tcl}} {"All files" {*}}}]
    if {$f eq ""} { return }
    set dbFile $f
    tb::saveDb
}

# --------------------------------------------------
# Filters / table
# --------------------------------------------------
proc tb::allSuites {} {
    variable tests
    set suites {all}
    foreach t $tests {
        set s [dict get $t suite]
        if {[lsearch -exact $suites $s] < 0} {
            lappend suites $s
        }
    }
    return [lsort -dictionary $suites]
}

proc tb::matchesFilters {t} {
    variable filterDomain
    variable filterSuite
    variable filterStatus
    variable searchText

    if {$filterDomain ne "all" && [dict get $t domain] ne $filterDomain} {
        return 0
    }
    if {$filterSuite ne "all" && [dict get $t suite] ne $filterSuite} {
        return 0
    }
    if {$filterStatus ne "all" && [dict get $t lastStatus] ne $filterStatus} {
        return 0
    }

    set needle [string trim [string tolower $searchText]]
    if {$needle ne ""} {
        set hay [string tolower \
            "[dict get $t id] [dict get $t name] [dict get $t suite] [dict get $t tags] [dict get $t description]"]
        if {[string first $needle $hay] < 0} {
            return 0
        }
    }

    return 1
}

proc tb::refreshSuiteFilterCombo {} {
    .filters.suiteC configure -values [tb::allSuites]
    if {[lsearch -exact [tb::allSuites] $::tb::filterSuite] < 0} {
        set ::tb::filterSuite "all"
    }
}

proc tb::refreshTable {} {
    variable ui
    variable tests

    tb::refreshSuiteFilterCombo

    set tree $ui(tree)
    foreach item [$tree children {}] {
        $tree delete $item
    }

    set idx 0
    foreach t $tests {
        if {![tb::matchesFilters $t]} {
            incr idx
            continue
        }

        set item [$tree insert {} end -id "row$idx" -values [list \
            $idx \
            [dict get $t id] \
            [dict get $t name] \
            [dict get $t suite] \
            [dict get $t domain] \
            [dict get $t priority] \
            [dict get $t lastStatus]]]

        switch -- [dict get $t lastStatus] {
            passed { $tree item $item -tags passed }
            failed { $tree item $item -tags failed }
            running { $tree item $item -tags running }
            blocked { $tree item $item -tags blocked }
        }

        incr idx
    }

    tb::setStatus "tabella test aggiornata"
}

# --------------------------------------------------
# Editor
# --------------------------------------------------
proc tb::loadTestIntoEditor {index} {
    variable tests
    variable selectedIndex

    if {$index < 0 || $index >= [llength $tests]} {
        return
    }

    set selectedIndex $index
    set t [lindex $tests $index]

    foreach {var key} {
        tcId id
        tcName name
        tcSuite suite
        tcDomain domain
        tcPriority priority
        tcExpectedStatus expectedStatus
        tcLastStatus lastStatus
        tcDescription description
        tcConfigPath configPath
        tcWorkflowPath workflowPath
        tcOutputDir outputDir
        tcLogPath logPath
        tcMetricsPath metricsPath
        tcTags tags
        tcNotes notes
        tcCreatedAt createdAt
    } {
        set ::tb::$var [dict get $t $key]
    }

    tb::populateNotesWidget
    tb::setStatus "test selezionato"
}

proc tb::onTreeSelect {} {
    variable ui
    set tree $ui(tree)
    set sel [$tree selection]
    if {$sel eq ""} { return }

    set item [lindex $sel 0]
    set index [$tree set $item 0]
    tb::loadTestIntoEditor $index
}

proc tb::buildTestDictFromEditor {} {
    tb::readNotesWidget

    if {[string trim $::tb::tcId] eq ""} {
        set ::tb::tcId [tb::nextTestId]
    }
    if {[string trim $::tb::tcCreatedAt] eq ""} {
        set ::tb::tcCreatedAt [tb::nowString]
    }

    return [dict create \
        id             $::tb::tcId \
        name           $::tb::tcName \
        suite          $::tb::tcSuite \
        domain         $::tb::tcDomain \
        priority       $::tb::tcPriority \
        expectedStatus $::tb::tcExpectedStatus \
        lastStatus     $::tb::tcLastStatus \
        description    $::tb::tcDescription \
        configPath     $::tb::tcConfigPath \
        workflowPath   $::tb::tcWorkflowPath \
        outputDir      $::tb::tcOutputDir \
        logPath        $::tb::tcLogPath \
        metricsPath    $::tb::tcMetricsPath \
        tags           $::tb::tcTags \
        notes          $::tb::tcNotes \
        createdAt      $::tb::tcCreatedAt]
}

proc tb::validateEditor {} {
    if {[string trim $::tb::tcName] eq ""} {
        tk_messageBox -icon warning -title "Validazione" \
            -message "Il nome del test è obbligatorio."
        return 0
    }
    if {[string trim $::tb::tcSuite] eq ""} {
        tk_messageBox -icon warning -title "Validazione" \
            -message "La suite è obbligatoria."
        return 0
    }
    return 1
}

# --------------------------------------------------
# CRUD
# --------------------------------------------------
proc tb::newTest {} {
    variable selectedIndex
    set selectedIndex -1
    tb::clearEditor
    set ::tb::tcId [tb::nextTestId]
    set ::tb::tcCreatedAt [tb::nowString]
    tb::populateNotesWidget
    tb::setStatus "nuovo test"
}

proc tb::saveCurrentTest {} {
    variable tests
    variable selectedIndex

    if {![tb::validateEditor]} {
        return
    }

    set t [tb::buildTestDictFromEditor]

    if {$selectedIndex < 0} {
        lappend tests $t
        set selectedIndex [expr {[llength $tests] - 1}]
    } else {
        set newList {}
        set i 0
        foreach old $tests {
            if {$i == $selectedIndex} {
                lappend newList $t
            } else {
                lappend newList $old
            }
            incr i
        }
        set tests $newList
    }

    tb::refreshTable
    tb::setStatus "test salvato"
}

proc tb::deleteCurrentTest {} {
    variable tests
    variable selectedIndex

    if {$selectedIndex < 0} {
        tk_messageBox -icon info -title "Elimina" \
            -message "Seleziona un test da eliminare."
        return
    }

    set ans [tk_messageBox -icon question -type yesno -title "Conferma" \
        -message "Eliminare il test selezionato?"]
    if {$ans ne "yes"} { return }

    set newList {}
    set i 0
    foreach t $tests {
        if {$i != $selectedIndex} {
            lappend newList $t
        }
        incr i
    }

    set tests $newList
    set selectedIndex -1
    tb::clearEditor
    tb::populateNotesWidget
    tb::refreshTable
    tb::setStatus "test eliminato"
}

# --------------------------------------------------
# Path helpers
# --------------------------------------------------
proc tb::chooseConfigPath {} {
    set f [tk_getOpenFile -title "Seleziona config file"]
    if {$f ne ""} { set ::tb::tcConfigPath $f }
}

proc tb::chooseWorkflowPath {} {
    set f [tk_getOpenFile -title "Seleziona workflow file" \
        -filetypes {{"Workflow files" {.wflow}} {"All files" {*}}}]
    if {$f ne ""} { set ::tb::tcWorkflowPath $f }
}

proc tb::chooseOutputDir {} {
    set d [tk_chooseDirectory -title "Seleziona output directory"]
    if {$d ne ""} { set ::tb::tcOutputDir $d }
}

proc tb::chooseLogPath {} {
    set f [tk_getOpenFile -title "Seleziona log file" \
        -filetypes {{"Log files" {.log .txt .out}} {"All files" {*}}}]
    if {$f ne ""} { set ::tb::tcLogPath $f }
}

proc tb::chooseMetricsPath {} {
    set f [tk_getOpenFile -title "Seleziona metrics file" \
        -filetypes {{"CSV files" {.csv}} {"All files" {*}}}]
    if {$f ne ""} { set ::tb::tcMetricsPath $f }
}

# --------------------------------------------------
# Quick actions
# --------------------------------------------------
proc tb::markSelectedStatus {status} {
    variable selectedIndex
    variable tests

    if {$selectedIndex < 0} {
        return
    }

    set newList {}
    set i 0
    foreach t $tests {
        if {$i == $selectedIndex} {
            dict set t lastStatus $status
            lappend newList $t
        } else {
            lappend newList $t
        }
        incr i
    }
    set tests $newList
    set ::tb::tcLastStatus $status
    tb::refreshTable
    tb::setStatus "stato test aggiornato a $status"
}

proc tb::loadSampleDb {} {
    variable tests
    variable selectedIndex
    set tests [tb::defaultTests]
    set selectedIndex -1
    tb::clearEditor
    tb::populateNotesWidget
    tb::refreshTable
    tb::setStatus "sample db caricato"
}

# --------------------------------------------------
# UI
# --------------------------------------------------
proc tb::buildUI {} {
    variable ui

    wm title . "Testbench Manager"
    wm geometry . 1520x940
    wm minsize . 1220 780
    ttk::style theme use clam

    ttk::frame .toolbar -padding 6
    pack .toolbar -fill x

    ttk::button .toolbar.new    -text "Nuovo test" -command tb::newTest
    ttk::button .toolbar.save   -text "Salva test" -command tb::saveCurrentTest
    ttk::button .toolbar.del    -text "Elimina test" -command tb::deleteCurrentTest
    ttk::button .toolbar.dbsave -text "Salva DB" -command tb::saveDb
    ttk::button .toolbar.dbas   -text "Salva DB come" -command tb::saveDbAs
    ttk::button .toolbar.sample -text "Sample DB" -command tb::loadSampleDb

    pack .toolbar.new .toolbar.save .toolbar.del .toolbar.dbsave .toolbar.dbas .toolbar.sample \
        -side left -padx 4

    ttk::frame .filters -padding 6
    pack .filters -fill x

    ttk::label .filters.domainL -text "Dominio:"
    ttk::combobox .filters.domainC -state readonly \
        -values {all radar satellite underwater hdl} \
        -textvariable tb::filterDomain

    ttk::label .filters.suiteL -text "Suite:"
    ttk::combobox .filters.suiteC -state readonly \
        -values {all} \
        -textvariable tb::filterSuite

    ttk::label .filters.statusL -text "Stato:"
    ttk::combobox .filters.statusC -state readonly \
        -values {all draft ready running passed failed blocked archived} \
        -textvariable tb::filterStatus

    ttk::label .filters.searchL -text "Cerca:"
    ttk::entry .filters.searchE -textvariable tb::searchText
    ttk::button .filters.apply  -text "Applica filtri" -command tb::refreshTable

    pack .filters.apply -side right -padx 3
    pack .filters.searchE -side right -padx 3
    pack .filters.searchL -side right -padx 3
    pack .filters.statusC -side right -padx 3
    pack .filters.statusL -side right -padx 3
    pack .filters.suiteC -side right -padx 3
    pack .filters.suiteL -side right -padx 3
    pack .filters.domainC -side right -padx 3
    pack .filters.domainL -side right -padx 3

    ttk::panedwindow .pw -orient horizontal
    pack .pw -fill both -expand 1

    ttk::frame .left -padding 6
    ttk::frame .right -padding 6
    .pw add .left -weight 3
    .pw add .right -weight 2

    # Left table
    ttk::labelframe .left.box -text "Test case" -padding 6
    pack .left.box -fill both -expand 1

    set ui(tree) [ttk::treeview .left.box.tree \
        -columns {idx id name suite domain priority lastStatus} \
        -show headings -selectmode browse]

    foreach {col txt w} {
        idx "#" 50
        id "ID" 80
        name "Nome" 290
        suite "Suite" 170
        domain "Dominio" 110
        priority "Priorità" 90
        lastStatus "Ultimo stato" 110
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

    bind $ui(tree) <<TreeviewSelect>> tb::onTreeSelect
    bind .filters.searchE <Return> {tb::refreshTable}

    $ui(tree) tag configure passed -foreground darkgreen
    $ui(tree) tag configure failed -foreground red
    $ui(tree) tag configure running -foreground blue
    $ui(tree) tag configure blocked -foreground darkorange3

    # Right form
    ttk::labelframe .right.form -text "Dettaglio test" -padding 10
    pack .right.form -fill both -expand 1

    grid columnconfigure .right.form 1 -weight 1

    ttk::label .right.form.l1 -text "ID:"
    ttk::entry .right.form.e1 -textvariable tb::tcId

    ttk::label .right.form.l2 -text "Nome:"
    ttk::entry .right.form.e2 -textvariable tb::tcName

    ttk::label .right.form.l3 -text "Suite:"
    ttk::entry .right.form.e3 -textvariable tb::tcSuite

    ttk::label .right.form.l4 -text "Dominio:"
    ttk::combobox .right.form.c4 -state readonly \
        -values {radar satellite underwater hdl} \
        -textvariable tb::tcDomain

    ttk::label .right.form.l5 -text "Priorità:"
    ttk::combobox .right.form.c5 -state readonly \
        -values {low medium high critical} \
        -textvariable tb::tcPriority

    ttk::label .right.form.l6 -text "Expected:"
    ttk::combobox .right.form.c6 -state readonly \
        -values {pass fail manual} \
        -textvariable tb::tcExpectedStatus

    ttk::label .right.form.l7 -text "Ultimo stato:"
    ttk::combobox .right.form.c7 -state readonly \
        -values {draft ready running passed failed blocked archived} \
        -textvariable tb::tcLastStatus

    ttk::label .right.form.l8 -text "Descrizione:"
    ttk::entry .right.form.e8 -textvariable tb::tcDescription

    ttk::label .right.form.l9 -text "Config path:"
    ttk::entry .right.form.e9 -textvariable tb::tcConfigPath
    ttk::button .right.form.b9 -text "..." -width 3 -command tb::chooseConfigPath

    ttk::label .right.form.l10 -text "Workflow path:"
    ttk::entry .right.form.e10 -textvariable tb::tcWorkflowPath
    ttk::button .right.form.b10 -text "..." -width 3 -command tb::chooseWorkflowPath

    ttk::label .right.form.l11 -text "Output dir:"
    ttk::entry .right.form.e11 -textvariable tb::tcOutputDir
    ttk::button .right.form.b11 -text "..." -width 3 -command tb::chooseOutputDir

    ttk::label .right.form.l12 -text "Log path:"
    ttk::entry .right.form.e12 -textvariable tb::tcLogPath
    ttk::button .right.form.b12 -text "..." -width 3 -command tb::chooseLogPath

    ttk::label .right.form.l13 -text "Metrics path:"
    ttk::entry .right.form.e13 -textvariable tb::tcMetricsPath
    ttk::button .right.form.b13 -text "..." -width 3 -command tb::chooseMetricsPath

    ttk::label .right.form.l14 -text "Tags:"
    ttk::entry .right.form.e14 -textvariable tb::tcTags

    ttk::label .right.form.l15 -text "Creato:"
    ttk::entry .right.form.e15 -textvariable tb::tcCreatedAt

    ttk::label .right.form.l16 -text "Note:"
    text .right.form.tnotes -height 8 -width 30 -wrap word

    for {set r 1} {$r <= 8} {incr r} {
        grid .right.form.l$r -row [expr {$r-1}] -column 0 -sticky w -pady 4
        if {$r in {4 5 6 7}} {
            set widget [expr {$r == 4 ? ".right.form.c4" : $r == 5 ? ".right.form.c5" : $r == 6 ? ".right.form.c6" : ".right.form.c7"}]
            grid $widget -row [expr {$r-1}] -column 1 -columnspan 2 -sticky ew -pady 4
        } else {
            grid .right.form.e$r -row [expr {$r-1}] -column 1 -columnspan 2 -sticky ew -pady 4
        }
    }

    foreach row {9 10 11 12 13} {
        grid .right.form.l$row -row [expr {$row-1}] -column 0 -sticky w -pady 4
        grid .right.form.e$row -row [expr {$row-1}] -column 1 -sticky ew -pady 4
        grid .right.form.b$row -row [expr {$row-1}] -column 2 -sticky ew -padx 4
    }

    grid .right.form.l14 -row 13 -column 0 -sticky w -pady 4
    grid .right.form.e14 -row 13 -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.form.l15 -row 14 -column 0 -sticky w -pady 4
    grid .right.form.e15 -row 14 -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.form.l16 -row 15 -column 0 -sticky nw -pady 4
    grid .right.form.tnotes -row 15 -column 1 -columnspan 2 -sticky ew -pady 4

    ttk::labelframe .right.actions -text "Azioni rapide" -padding 10
    pack .right.actions -fill x -pady 10

    ttk::button .right.actions.cfg -text "Apri config" -command {tb::openPath $::tb::tcConfigPath}
    ttk::button .right.actions.wf  -text "Apri workflow" -command {tb::openPath $::tb::tcWorkflowPath}
    ttk::button .right.actions.out -text "Apri output" -command {tb::openPath $::tb::tcOutputDir}
    ttk::button .right.actions.log -text "Apri log" -command {tb::openPath $::tb::tcLogPath}
    ttk::button .right.actions.met -text "Apri metrics" -command {tb::openPath $::tb::tcMetricsPath}

    pack .right.actions.cfg .right.actions.wf .right.actions.out .right.actions.log .right.actions.met \
        -fill x -pady 2

    ttk::labelframe .right.statusbox -text "Stato rapido" -padding 10
    pack .right.statusbox -fill x -pady 10

    ttk::button .right.statusbox.ready  -text "Mark READY"  -command {tb::markSelectedStatus ready}
    ttk::button .right.statusbox.run    -text "Mark RUNNING" -command {tb::markSelectedStatus running}
    ttk::button .right.statusbox.pass   -text "Mark PASSED" -command {tb::markSelectedStatus passed}
    ttk::button .right.statusbox.fail   -text "Mark FAILED" -command {tb::markSelectedStatus failed}
    ttk::button .right.statusbox.block  -text "Mark BLOCKED" -command {tb::markSelectedStatus blocked}

    pack .right.statusbox.ready .right.statusbox.run .right.statusbox.pass \
         .right.statusbox.fail .right.statusbox.block -fill x -pady 2

    ttk::separator .sep -orient horizontal
    pack .sep -fill x

    ttk::label .status -text "Stato: pronto" -padding 6
    pack .status -fill x
}

# --------------------------------------------------
# Main
# --------------------------------------------------
tb::buildUI
tb::loadDb
tb::refreshTable
tb::clearEditor
tb::populateNotesWidget
tb::setStatus "Testbench Manager pronto"