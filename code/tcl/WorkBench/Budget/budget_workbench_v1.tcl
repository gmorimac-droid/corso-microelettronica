#!/usr/bin/env wish

package require Tk 8.6

namespace eval bw {
    variable budgets {}
    variable dbFile "budget_db.tcl"
    variable selectedIndex -1

    variable filterCategory "all"
    variable filterStatus "all"
    variable searchText ""

    variable biId ""
    variable biName ""
    variable biCategory "processing"
    variable biUnit ""
    variable biAvailable ""
    variable biUsed ""
    variable biMargin ""
    variable biPercentUsed ""
    variable biStatus ""
    variable biNotes ""
    variable biCreatedAt ""

    variable ui
}

# --------------------------------------------------
# Utility
# --------------------------------------------------
proc bw::setStatus {msg} {
    .status configure -text "Stato: $msg"
}

proc bw::nowString {} {
    return [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
}

proc bw::toNumber {x} {
    if {[string trim $x] eq ""} { return "" }
    if {[string is double -strict $x]} { return $x }
    return ""
}

proc bw::fmtNumber {x} {
    if {$x eq ""} { return "" }
    return [format "%.6g" $x]
}

proc bw::nextBudgetId {} {
    variable budgets
    set maxNum 0
    foreach b $budgets {
        if {[dict exists $b id]} {
            set id [dict get $b id]
            if {[regexp {^BDG([0-9]+)$} $id -> num]} {
                if {$num > $maxNum} { set maxNum $num }
            }
        }
    }
    incr maxNum
    return [format "BDG%03d" $maxNum]
}

proc bw::computeMargin {available used} {
    set a [bw::toNumber $available]
    set u [bw::toNumber $used]
    if {$a eq "" || $u eq ""} { return "" }
    return [bw::fmtNumber [expr {$a - $u}]]
}

proc bw::computePercentUsed {available used} {
    set a [bw::toNumber $available]
    set u [bw::toNumber $used]
    if {$a eq "" || $u eq "" || $a == 0} { return "" }
    return [format "%.1f" [expr {100.0 * $u / $a}]]
}

proc bw::computeStatus {available used} {
    set a [bw::toNumber $available]
    set u [bw::toNumber $used]

    if {$a eq "" || $u eq ""} {
        return "WARN"
    }
    if {$u > $a} {
        return "FAIL"
    }

    set pct [expr {$a == 0 ? 0 : (100.0 * $u / $a)}]
    if {$pct > 90.0} {
        return "WARN"
    }
    return "OK"
}

proc bw::allCategories {} {
    variable budgets
    set cats {all}
    foreach b $budgets {
        set c [dict get $b category]
        if {[lsearch -exact $cats $c] < 0} {
            lappend cats $c
        }
    }
    return [lsort -dictionary $cats]
}

proc bw::refreshCategoryFilter {} {
    .filters.catC configure -values [bw::allCategories]
    if {[lsearch -exact [bw::allCategories] $::bw::filterCategory] < 0} {
        set ::bw::filterCategory "all"
    }
}

# --------------------------------------------------
# Editor helpers
# --------------------------------------------------
proc bw::clearEditor {} {
    set ::bw::biId ""
    set ::bw::biName ""
    set ::bw::biCategory "processing"
    set ::bw::biUnit ""
    set ::bw::biAvailable ""
    set ::bw::biUsed ""
    set ::bw::biMargin ""
    set ::bw::biPercentUsed ""
    set ::bw::biStatus ""
    set ::bw::biNotes ""
    set ::bw::biCreatedAt ""

    if {[winfo exists .right.form.tnotes]} {
        .right.form.tnotes delete 1.0 end
    }
}

proc bw::populateNotesWidget {} {
    if {[winfo exists .right.form.tnotes]} {
        .right.form.tnotes delete 1.0 end
        .right.form.tnotes insert end $::bw::biNotes
    }
}

proc bw::readNotesWidget {} {
    if {[winfo exists .right.form.tnotes]} {
        set ::bw::biNotes [string trim [.right.form.tnotes get 1.0 end]]
    }
}

proc bw::recomputeEditorDerivedFields {} {
    set ::bw::biMargin [bw::computeMargin $::bw::biAvailable $::bw::biUsed]
    set pct [bw::computePercentUsed $::bw::biAvailable $::bw::biUsed]
    if {$pct ne ""} {
        set ::bw::biPercentUsed "${pct}%"
    } else {
        set ::bw::biPercentUsed ""
    }
    set ::bw::biStatus [bw::computeStatus $::bw::biAvailable $::bw::biUsed]
}

# --------------------------------------------------
# Sample DB
# --------------------------------------------------
proc bw::defaultBudgets {} {
    return {
        {
            id BDG001
            name "Radar latency chain"
            category latency
            unit ms
            available 25
            used 18
            margin 7
            percentUsed 72.0%
            status OK
            notes "Budget nominale preprocess+detect+track"
            createdAt "2026-03-31 10:05:00"
        }
        {
            id BDG002
            name "Satellite power margin"
            category power
            unit W
            available 150
            used 138
            margin 12
            percentUsed 92.0%
            status WARN
            notes "Vicino limite in downlink mode"
            createdAt "2026-03-31 10:20:00"
        }
        {
            id BDG003
            name "HDL DSP budget"
            category fpga_resources
            unit DSP
            available 220
            used 241
            margin -21
            percentUsed 109.5%
            status FAIL
            notes "Superato budget dopo nuova pipeline"
            createdAt "2026-03-31 11:15:00"
        }
        {
            id BDG004
            name "Underwater storage session"
            category storage
            unit GB
            available 512
            used 180
            margin 332
            percentUsed 35.2%
            status OK
            notes "Ampio margine disponibile"
            createdAt "2026-03-31 12:00:00"
        }
    }
}

# --------------------------------------------------
# Persistence
# --------------------------------------------------
proc bw::loadDb {} {
    variable dbFile
    variable budgets

    if {[file exists $dbFile]} {
        if {[catch {
            set f [open $dbFile r]
            set budgets [read $f]
            close $f
        } err]} {
            set budgets [bw::defaultBudgets]
            bw::setStatus "errore caricamento db"
            return
        }
    } else {
        set budgets [bw::defaultBudgets]
    }

    bw::setStatus "database budget caricato"
}

proc bw::saveDb {} {
    variable dbFile
    variable budgets

    if {[catch {
        set f [open $dbFile w]
        puts $f $budgets
        close $f
    } err]} {
        tk_messageBox -icon error -title "Errore" \
            -message "Impossibile salvare il database:\n$err"
        return
    }

    bw::setStatus "database budget salvato"
}

proc bw::saveDbAs {} {
    variable dbFile
    set f [tk_getSaveFile \
        -title "Salva database budget" \
        -defaultextension ".tcl" \
        -filetypes {{"Tcl database" {.tcl}} {"All files" {*}}}]
    if {$f eq ""} { return }
    set dbFile $f
    bw::saveDb
}

# --------------------------------------------------
# Filtering / table
# --------------------------------------------------
proc bw::matchesFilters {b} {
    variable filterCategory
    variable filterStatus
    variable searchText

    if {$filterCategory ne "all" && [dict get $b category] ne $filterCategory} {
        return 0
    }
    if {$filterStatus ne "all" && [dict get $b status] ne $filterStatus} {
        return 0
    }

    set needle [string trim [string tolower $searchText]]
    if {$needle ne ""} {
        set hay [string tolower \
            "[dict get $b id] [dict get $b name] [dict get $b category] [dict get $b unit] [dict get $b notes]"]
        if {[string first $needle $hay] < 0} {
            return 0
        }
    }

    return 1
}

proc bw::refreshSummary {} {
    variable budgets
    variable ui

    set ok 0
    set warn 0
    set fail 0

    foreach b $budgets {
        switch -- [dict get $b status] {
            OK   { incr ok }
            WARN { incr warn }
            FAIL { incr fail }
        }
    }

    $ui(summary) configure -text "OK=$ok   WARN=$warn   FAIL=$fail"
}

proc bw::refreshTable {} {
    variable ui
    variable budgets

    bw::refreshCategoryFilter

    set tree $ui(tree)
    foreach item [$tree children {}] {
        $tree delete $item
    }

    set idx 0
    foreach b $budgets {
        if {![bw::matchesFilters $b]} {
            incr idx
            continue
        }

        set item [$tree insert {} end -id "row$idx" -values [list \
            $idx \
            [dict get $b id] \
            [dict get $b name] \
            [dict get $b category] \
            [dict get $b available] \
            [dict get $b used] \
            [dict get $b margin] \
            [dict get $b percentUsed] \
            [dict get $b status]]]

        switch -- [dict get $b status] {
            OK   { $tree item $item -tags ok }
            WARN { $tree item $item -tags warn }
            FAIL { $tree item $item -tags fail }
        }

        incr idx
    }

    bw::refreshSummary
    bw::setStatus "tabella budget aggiornata"
}

# --------------------------------------------------
# Selection / editor
# --------------------------------------------------
proc bw::loadBudgetIntoEditor {index} {
    variable budgets
    variable selectedIndex

    if {$index < 0 || $index >= [llength $budgets]} {
        return
    }

    set selectedIndex $index
    set b [lindex $budgets $index]

    foreach {var key} {
        biId id
        biName name
        biCategory category
        biUnit unit
        biAvailable available
        biUsed used
        biMargin margin
        biPercentUsed percentUsed
        biStatus status
        biNotes notes
        biCreatedAt createdAt
    } {
        set ::bw::$var [dict get $b $key]
    }

    bw::populateNotesWidget
    bw::setStatus "budget selezionato"
}

proc bw::onTreeSelect {} {
    variable ui
    set tree $ui(tree)
    set sel [$tree selection]
    if {$sel eq ""} { return }

    set item [lindex $sel 0]
    set index [$tree set $item 0]
    bw::loadBudgetIntoEditor $index
}

proc bw::buildBudgetDictFromEditor {} {
    bw::readNotesWidget
    bw::recomputeEditorDerivedFields

    if {[string trim $::bw::biId] eq ""} {
        set ::bw::biId [bw::nextBudgetId]
    }
    if {[string trim $::bw::biCreatedAt] eq ""} {
        set ::bw::biCreatedAt [bw::nowString]
    }

    return [dict create \
        id          $::bw::biId \
        name        $::bw::biName \
        category    $::bw::biCategory \
        unit        $::bw::biUnit \
        available   $::bw::biAvailable \
        used        $::bw::biUsed \
        margin      $::bw::biMargin \
        percentUsed $::bw::biPercentUsed \
        status      $::bw::biStatus \
        notes       $::bw::biNotes \
        createdAt   $::bw::biCreatedAt]
}

proc bw::validateEditor {} {
    if {[string trim $::bw::biName] eq ""} {
        tk_messageBox -icon warning -title "Validazione" \
            -message "Il nome budget è obbligatorio."
        return 0
    }

    if {[string trim $::bw::biAvailable] ne "" && [bw::toNumber $::bw::biAvailable] eq ""} {
        tk_messageBox -icon warning -title "Validazione" \
            -message "Il campo 'Available' deve essere numerico."
        return 0
    }

    if {[string trim $::bw::biUsed] ne "" && [bw::toNumber $::bw::biUsed] eq ""} {
        tk_messageBox -icon warning -title "Validazione" \
            -message "Il campo 'Used' deve essere numerico."
        return 0
    }

    return 1
}

# --------------------------------------------------
# CRUD
# --------------------------------------------------
proc bw::newBudget {} {
    variable selectedIndex
    set selectedIndex -1
    bw::clearEditor
    set ::bw::biId [bw::nextBudgetId]
    set ::bw::biCreatedAt [bw::nowString]
    bw::populateNotesWidget
    bw::setStatus "nuovo budget"
}

proc bw::saveCurrentBudget {} {
    variable budgets
    variable selectedIndex

    if {![bw::validateEditor]} {
        return
    }

    set b [bw::buildBudgetDictFromEditor]

    if {$selectedIndex < 0} {
        lappend budgets $b
        set selectedIndex [expr {[llength $budgets] - 1}]
    } else {
        set newList {}
        set i 0
        foreach old $budgets {
            if {$i == $selectedIndex} {
                lappend newList $b
            } else {
                lappend newList $old
            }
            incr i
        }
        set budgets $newList
    }

    bw::refreshTable
    bw::setStatus "budget salvato"
}

proc bw::deleteCurrentBudget {} {
    variable budgets
    variable selectedIndex

    if {$selectedIndex < 0} {
        tk_messageBox -icon info -title "Elimina" \
            -message "Seleziona un budget da eliminare."
        return
    }

    set ans [tk_messageBox -icon question -type yesno -title "Conferma" \
        -message "Eliminare il budget selezionato?"]
    if {$ans ne "yes"} { return }

    set newList {}
    set i 0
    foreach b $budgets {
        if {$i != $selectedIndex} {
            lappend newList $b
        }
        incr i
    }

    set budgets $newList
    set selectedIndex -1
    bw::clearEditor
    bw::populateNotesWidget
    bw::refreshTable
    bw::setStatus "budget eliminato"
}

proc bw::loadSampleDb {} {
    variable budgets
    variable selectedIndex
    set budgets [bw::defaultBudgets]
    set selectedIndex -1
    bw::clearEditor
    bw::populateNotesWidget
    bw::refreshTable
    bw::setStatus "sample db caricato"
}

# --------------------------------------------------
# UI
# --------------------------------------------------
proc bw::buildUI {} {
    variable ui

    wm title . "Budget Workbench"
    wm geometry . 1500x920
    wm minsize . 1200 760
    ttk::style theme use clam

    ttk::frame .toolbar -padding 6
    pack .toolbar -fill x

    ttk::button .toolbar.new    -text "Nuovo budget" -command bw::newBudget
    ttk::button .toolbar.save   -text "Salva budget" -command bw::saveCurrentBudget
    ttk::button .toolbar.del    -text "Elimina budget" -command bw::deleteCurrentBudget
    ttk::button .toolbar.dbsave -text "Salva DB" -command bw::saveDb
    ttk::button .toolbar.dbas   -text "Salva DB come" -command bw::saveDbAs
    ttk::button .toolbar.sample -text "Sample DB" -command bw::loadSampleDb

    pack .toolbar.new .toolbar.save .toolbar.del .toolbar.dbsave .toolbar.dbas .toolbar.sample \
        -side left -padx 4

    ttk::frame .filters -padding 6
    pack .filters -fill x

    ttk::label .filters.catL -text "Categoria:"
    ttk::combobox .filters.catC -state readonly \
        -values {all} \
        -textvariable bw::filterCategory

    ttk::label .filters.statusL -text "Stato:"
    ttk::combobox .filters.statusC -state readonly \
        -values {all OK WARN FAIL} \
        -textvariable bw::filterStatus

    ttk::label .filters.searchL -text "Cerca:"
    ttk::entry .filters.searchE -textvariable bw::searchText
    ttk::button .filters.apply -text "Applica filtri" -command bw::refreshTable

    pack .filters.apply -side right -padx 3
    pack .filters.searchE -side right -padx 3
    pack .filters.searchL -side right -padx 3
    pack .filters.statusC -side right -padx 3
    pack .filters.statusL -side right -padx 3
    pack .filters.catC -side right -padx 3
    pack .filters.catL -side right -padx 3

    ttk::panedwindow .pw -orient horizontal
    pack .pw -fill both -expand 1

    ttk::frame .left -padding 6
    ttk::frame .right -padding 6
    .pw add .left -weight 3
    .pw add .right -weight 2

    # Left table
    ttk::labelframe .left.box -text "Budget items" -padding 6
    pack .left.box -fill both -expand 1

    set ui(tree) [ttk::treeview .left.box.tree \
        -columns {idx id name category available used margin percentUsed status} \
        -show headings -selectmode browse]

    foreach {col txt w} {
        idx "#" 45
        id "ID" 80
        name "Name" 260
        category "Category" 140
        available "Available" 100
        used "Used" 100
        margin "Margin" 100
        percentUsed "% Used" 90
        status "Status" 80
    } {
        $ui(tree) heading $col -text $txt
        $ui(tree) column $col -width $w -anchor center
    }

    ttk::scrollbar .left.box.vsb -orient vertical -command "$ui(tree) yview"
    ttk::scrollbar .left.box.hsb -orient horizontal -command "$ui(tree) xview"
    $ui(tree) configure -yscrollcommand ".left.box.vsb set" -xscrollcommand ".left.box.hsb set"

    grid $ui(tree) -row 0 -column 0 -sticky nsew
    grid .left.box.vsb -row 0 -column 1 -sticky ns
    grid .left.box.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .left.box 0 -weight 1
    grid columnconfigure .left.box 0 -weight 1

    bind $ui(tree) <<TreeviewSelect>> bw::onTreeSelect
    bind .filters.searchE <Return> {bw::refreshTable}

    $ui(tree) tag configure ok -foreground darkgreen
    $ui(tree) tag configure warn -foreground darkorange3
    $ui(tree) tag configure fail -foreground red

    # Right form
    ttk::labelframe .right.form -text "Dettaglio budget" -padding 10
    pack .right.form -fill both -expand 1

    grid columnconfigure .right.form 1 -weight 1

    ttk::label .right.form.l1 -text "ID:"
    ttk::entry .right.form.e1 -textvariable bw::biId

    ttk::label .right.form.l2 -text "Nome:"
    ttk::entry .right.form.e2 -textvariable bw::biName

    ttk::label .right.form.l3 -text "Categoria:"
    ttk::combobox .right.form.c3 -state readonly \
        -values {processing latency power bandwidth storage memory fpga_resources link_budget detection coverage compute custom} \
        -textvariable bw::biCategory

    ttk::label .right.form.l4 -text "Unità:"
    ttk::entry .right.form.e4 -textvariable bw::biUnit

    ttk::label .right.form.l5 -text "Available:"
    ttk::entry .right.form.e5 -textvariable bw::biAvailable

    ttk::label .right.form.l6 -text "Used:"
    ttk::entry .right.form.e6 -textvariable bw::biUsed

    ttk::label .right.form.l7 -text "Margin:"
    ttk::entry .right.form.e7 -textvariable bw::biMargin -state readonly

    ttk::label .right.form.l8 -text "% Used:"
    ttk::entry .right.form.e8 -textvariable bw::biPercentUsed -state readonly

    ttk::label .right.form.l9 -text "Status:"
    ttk::entry .right.form.e9 -textvariable bw::biStatus -state readonly

    ttk::label .right.form.l10 -text "Creato:"
    ttk::entry .right.form.e10 -textvariable bw::biCreatedAt

    ttk::label .right.form.l11 -text "Note:"
    text .right.form.tnotes -height 8 -width 30 -wrap word

    grid .right.form.l1  -row 0 -column 0 -sticky w -pady 4
    grid .right.form.e1  -row 0 -column 1 -sticky ew -pady 4

    grid .right.form.l2  -row 1 -column 0 -sticky w -pady 4
    grid .right.form.e2  -row 1 -column 1 -sticky ew -pady 4

    grid .right.form.l3  -row 2 -column 0 -sticky w -pady 4
    grid .right.form.c3  -row 2 -column 1 -sticky ew -pady 4

    grid .right.form.l4  -row 3 -column 0 -sticky w -pady 4
    grid .right.form.e4  -row 3 -column 1 -sticky ew -pady 4

    grid .right.form.l5  -row 4 -column 0 -sticky w -pady 4
    grid .right.form.e5  -row 4 -column 1 -sticky ew -pady 4

    grid .right.form.l6  -row 5 -column 0 -sticky w -pady 4
    grid .right.form.e6  -row 5 -column 1 -sticky ew -pady 4

    grid .right.form.l7  -row 6 -column 0 -sticky w -pady 4
    grid .right.form.e7  -row 6 -column 1 -sticky ew -pady 4

    grid .right.form.l8  -row 7 -column 0 -sticky w -pady 4
    grid .right.form.e8  -row 7 -column 1 -sticky ew -pady 4

    grid .right.form.l9  -row 8 -column 0 -sticky w -pady 4
    grid .right.form.e9  -row 8 -column 1 -sticky ew -pady 4

    grid .right.form.l10 -row 9 -column 0 -sticky w -pady 4
    grid .right.form.e10 -row 9 -column 1 -sticky ew -pady 4

    grid .right.form.l11 -row 10 -column 0 -sticky nw -pady 4
    grid .right.form.tnotes -row 10 -column 1 -sticky ew -pady 4

    ttk::frame .right.actions -padding 6
    pack .right.actions -fill x

    ttk::button .right.actions.recompute -text "Ricalcola" -command bw::recomputeEditorDerivedFields
    ttk::button .right.actions.apply -text "Applica e salva" -command bw::saveCurrentBudget

    pack .right.actions.recompute .right.actions.apply -side left -padx 4

    ttk::separator .sep1 -orient horizontal
    pack .sep1 -fill x

    set ui(summary) [ttk::label .summary -text "OK=0   WARN=0   FAIL=0" -padding 6]
    pack .summary -fill x

    ttk::separator .sep2 -orient horizontal
    pack .sep2 -fill x

    ttk::label .status -text "Stato: pronto" -padding 6
    pack .status -fill x

    foreach v {bw::biAvailable bw::biUsed} {
        trace add variable $v write {apply {{args} {
            after idle bw::recomputeEditorDerivedFields
        }}}
    }
}

# --------------------------------------------------
# Main
# --------------------------------------------------
bw::buildUI
bw::loadDb
bw::refreshTable
bw::clearEditor
bw::populateNotesWidget
bw::setStatus "Budget Workbench pronto"