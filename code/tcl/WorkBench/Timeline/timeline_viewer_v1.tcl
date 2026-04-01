#!/usr/bin/env wish

package require Tk 8.6

namespace eval tl {
    variable events {}
    variable currentFile ""

    variable zoom 12.0
    variable rowHeight 34
    variable leftMargin 90
    variable topMargin 30
    variable rightPanelWidth 360

    variable filterCategory "all"
    variable filterText ""

    variable selectedIndex -1

    variable ui
}

# --------------------------------------------------
# Utility
# --------------------------------------------------
proc tl::setStatus {msg} {
    .status configure -text "Stato: $msg"
}

proc tl::parseCsvLine {line} {
    return [split $line ","]
}

proc tl::toNumber {x} {
    if {[string trim $x] eq ""} { return "" }
    if {[string is double -strict $x]} { return $x }
    return ""
}

proc tl::categoryColor {cat} {
    switch -- [string tolower $cat] {
        scenario   { return "#d9ead3" }
        processing { return "#cfe2f3" }
        tracking   { return "#fff2cc" }
        log        { return "#f4cccc" }
        validation { return "#ead1dc" }
        launch     { return "#d0e0e3" }
        test       { return "#fce5cd" }
        default    { return "#eeeeee" }
    }
}

proc tl::statusOutline {status} {
    switch -- [string tolower $status] {
        ok      { return "darkgreen" }
        warn    { return "darkorange3" }
        fail    { return "red" }
        running { return "blue" }
        default { return "black" }
    }
}

proc tl::statusWidth {status} {
    switch -- [string tolower $status] {
        ok - warn - fail - running { return 3 }
        default { return 1 }
    }
}

proc tl::allCategories {} {
    variable events
    set cats {all}
    foreach ev $events {
        set c [dict get $ev category]
        if {[lsearch -exact $cats $c] < 0} {
            lappend cats $c
        }
    }
    return [lsort -dictionary $cats]
}

proc tl::refreshCategoryFilter {} {
    .top.filterCat configure -values [tl::allCategories]
    if {[lsearch -exact [tl::allCategories] $::tl::filterCategory] < 0} {
        set ::tl::filterCategory "all"
    }
}

# --------------------------------------------------
# Data loading
# --------------------------------------------------
proc tl::loadCsvFile {path} {
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

    if {[llength $lines] < 2} {
        return {}
    }

    set header [tl::parseCsvLine [lindex $lines 0]]
    set rows {}

    foreach line [lrange $lines 1 end] {
        set cols [tl::parseCsvLine $line]
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

        if {![dict exists $row start] || ![dict exists $row end]} {
            continue
        }

        set s [tl::toNumber [dict get $row start]]
        set e [tl::toNumber [dict get $row end]]
        if {$s eq "" || $e eq ""} {
            continue
        }

        if {![dict exists $row category]} { dict set row category "default" }
        if {![dict exists $row label]}    { dict set row label "event" }
        if {![dict exists $row status]}   { dict set row status "" }
        if {![dict exists $row details]}  { dict set row details "" }

        lappend rows $row
    }

    return $rows
}

proc tl::loadSampleData {} {
    set ::tl::events {
        {start 0  end 12 category scenario   label "Scenario Init" status ok      details "Setup iniziale scenario"}
        {start 10 end 28 category processing label "Preprocess"    status ok      details "Preprocessing radar"}
        {start 30 end 44 category processing label "Detect"        status warn    details "Soglia adattiva attiva"}
        {start 45 end 70 category tracking   label "Track #1"      status ok      details "Track stabile"}
        {start 52 end 60 category log        label "Warning event" status warn    details "Noisy sector"}
        {start 72 end 90 category validation label "Validation"    status fail    details "RMSE fuori soglia"}
        {start 15 end 22 category test       label "Smoke Test A"  status ok      details "Test rapido completato"}
        {start 24 end 50 category launch     label "Batch Run"     status running details "Launcher pipeline"}
    }
    set ::tl::currentFile ""
    tl::refreshCategoryFilter
    tl::renderTimeline
    tl::setStatus "sample timeline caricata"
}

proc tl::openCsv {} {
    variable currentFile
    variable events

    set f [tk_getOpenFile \
        -title "Apri eventi timeline" \
        -filetypes {{"CSV files" {.csv}} {"All files" {*}}}]
    if {$f eq ""} { return }

    if {[catch {
        set events [tl::loadCsvFile $f]
        set currentFile $f
    } err]} {
        tk_messageBox -icon error -title "Errore" -message $err
        return
    }

    .top.fileEntry delete 0 end
    .top.fileEntry insert 0 $f
    tl::refreshCategoryFilter
    tl::renderTimeline
    tl::setStatus "timeline caricata"
}

proc tl::reloadCsv {} {
    variable currentFile
    variable events

    if {$currentFile eq ""} {
        tk_messageBox -icon info -title "Reload" -message "Nessun file timeline caricato."
        return
    }

    if {[catch {
        set events [tl::loadCsvFile $currentFile]
    } err]} {
        tk_messageBox -icon error -title "Errore" -message $err
        return
    }

    tl::refreshCategoryFilter
    tl::renderTimeline
    tl::setStatus "timeline ricaricata"
}

# --------------------------------------------------
# Filtering
# --------------------------------------------------
proc tl::matchesFilters {ev} {
    variable filterCategory
    variable filterText

    if {$filterCategory ne "all"} {
        if {[dict get $ev category] ne $filterCategory} {
            return 0
        }
    }

    set needle [string trim [string tolower $filterText]]
    if {$needle ne ""} {
        set hay [string tolower \
            "[dict get $ev label] [dict get $ev category] [dict get $ev status] [dict get $ev details]"]
        if {[string first $needle $hay] < 0} {
            return 0
        }
    }

    return 1
}

proc tl::filteredEvents {} {
    variable events
    set out {}
    foreach ev $events {
        if {[tl::matchesFilters $ev]} {
            lappend out $ev
        }
    }
    return $out
}

# --------------------------------------------------
# Timeline rendering
# --------------------------------------------------
proc tl::clearCanvas {} {
    variable ui
    $ui(canvas) delete all
}

proc tl::timeRange {events} {
    if {[llength $events] == 0} {
        return {0 100}
    }

    set minT ""
    set maxT ""

    foreach ev $events {
        set s [dict get $ev start]
        set e [dict get $ev end]
        if {$minT eq "" || $s < $minT} { set minT $s }
        if {$maxT eq "" || $e > $maxT} { set maxT $e }
    }

    return [list $minT $maxT]
}

proc tl::xForTime {t} {
    variable leftMargin
    variable zoom
    expr {$leftMargin + ($t * $zoom)}
}

proc tl::renderAxis {events} {
    variable ui
    variable leftMargin
    variable topMargin
    variable rowHeight

    lassign [tl::timeRange $events] minT maxT

    set y0 18
    set xStart [tl::xForTime $minT]
    set xEnd   [tl::xForTime $maxT]

    $ui(canvas) create line $xStart $y0 $xEnd $y0 -width 2

    set t $minT
    while {$t <= $maxT} {
        set x [tl::xForTime $t]
        $ui(canvas) create line $x $y0 $x [expr {$y0 + 8}]
        $ui(canvas) create text $x [expr {$y0 - 8}] -text $t -anchor s -font "TkDefaultFont 9"
        incr t 10
    }

    set totalRows [llength $events]
    set h [expr {$topMargin + ($totalRows+1) * $rowHeight}]
    $ui(canvas) configure -scrollregion [list 0 0 [expr {$xEnd + 200}] $h]
}

proc tl::renderTimeline {} {
    variable ui
    variable rowHeight
    variable topMargin

    tl::clearCanvas
    tl::clearDetail

    set evs [tl::filteredEvents]
    tl::renderAxis $evs

    set row 0
    foreach ev $evs {
        set y1 [expr {$topMargin + $row * $rowHeight}]
        set y2 [expr {$y1 + 22}]
        set x1 [tl::xForTime [dict get $ev start]]
        set x2 [tl::xForTime [dict get $ev end]]

        set cat [dict get $ev category]
        set label [dict get $ev label]
        set status [dict get $ev status]

        # Label left
        $ui(canvas) create text 10 [expr {$y1 + 11}] \
            -text $label -anchor w -font "TkDefaultFont 9"

        # Bar
        set rect [$ui(canvas) create rectangle $x1 $y1 $x2 $y2 \
            -fill [tl::categoryColor $cat] \
            -outline [tl::statusOutline $status] \
            -width [tl::statusWidth $status]]

        set txt [$ui(canvas) create text [expr {($x1+$x2)/2}] [expr {$y1 + 11}] \
            -text "$label ([dict get $ev start]-[dict get $ev end])" \
            -font "TkDefaultFont 9"]

        $ui(canvas) addtag "event$row" withtag $rect
        $ui(canvas) addtag "event$row" withtag $txt

        set ::tl::ui(event,$row) $ev
        incr row
    }
}

# --------------------------------------------------
# Detail panel
# --------------------------------------------------
proc tl::clearDetail {} {
    .right.detail.startV configure -text ""
    .right.detail.endV configure -text ""
    .right.detail.catV configure -text ""
    .right.detail.labelV configure -text ""
    .right.detail.statusV configure -text ""
    .right.detail.detailsV configure -text ""
}

proc tl::showDetail {idx} {
    if {![info exists ::tl::ui(event,$idx)]} {
        return
    }

    set ev $::tl::ui(event,$idx)

    .right.detail.startV configure -text [dict get $ev start]
    .right.detail.endV configure -text [dict get $ev end]
    .right.detail.catV configure -text [dict get $ev category]
    .right.detail.labelV configure -text [dict get $ev label]
    .right.detail.statusV configure -text [dict get $ev status]
    .right.detail.detailsV configure -text [dict get $ev details]

    set ::tl::selectedIndex $idx
    tl::setStatus "evento selezionato"
}

proc tl::onCanvasClick {x y} {
    variable ui

    set items [$ui(canvas) find overlapping $x $y $x $y]
    foreach item $items {
        foreach tag [$ui(canvas) gettags $item] {
            if {[regexp {^event([0-9]+)$} $tag -> idx]} {
                tl::showDetail $idx
                return
            }
        }
    }
}

# --------------------------------------------------
# Zoom
# --------------------------------------------------
proc tl::zoomIn {} {
    set ::tl::zoom [expr {$::tl::zoom * 1.25}]
    tl::renderTimeline
}

proc tl::zoomOut {} {
    set ::tl::zoom [expr {$::tl::zoom / 1.25}]
    if {$::tl::zoom < 2} { set ::tl::zoom 2 }
    tl::renderTimeline
}

# --------------------------------------------------
# UI
# --------------------------------------------------
proc tl::buildUI {} {
    variable ui

    wm title . "Timeline Viewer"
    wm geometry . 1500x900
    wm minsize . 1180 760
    ttk::style theme use clam

    ttk::frame .top -padding 6
    pack .top -fill x

    ttk::button .top.openBtn   -text "Apri CSV" -command tl::openCsv
    ttk::button .top.reloadBtn -text "Ricarica" -command tl::reloadCsv
    ttk::button .top.sampleBtn -text "Sample" -command tl::loadSampleData
    ttk::button .top.zoomInBtn -text "Zoom +" -command tl::zoomIn
    ttk::button .top.zoomOutBtn -text "Zoom -" -command tl::zoomOut

    ttk::label .top.fileL -text "File:"
    entry .top.fileEntry

    ttk::label .top.catL -text "Categoria:"
    ttk::combobox .top.filterCat -state readonly \
        -values {all} \
        -textvariable tl::filterCategory

    ttk::label .top.searchL -text "Filtro:"
    ttk::entry .top.searchE -textvariable tl::filterText
    ttk::button .top.applyBtn -text "Applica" -command tl::renderTimeline

    pack .top.openBtn .top.reloadBtn .top.sampleBtn .top.zoomInBtn .top.zoomOutBtn -side left -padx 3
    pack .top.applyBtn -side right -padx 3
    pack .top.searchE -side right -padx 3
    pack .top.searchL -side right -padx 3
    pack .top.filterCat -side right -padx 3
    pack .top.catL -side right -padx 3
    pack .top.fileEntry -side right -fill x -expand 1 -padx 3
    pack .top.fileL -side right -padx 3

    ttk::panedwindow .pw -orient horizontal
    pack .pw -fill both -expand 1

    ttk::frame .left -padding 6
    ttk::frame .right -padding 6
    .pw add .left -weight 4
    .pw add .right -weight 1

    ttk::labelframe .left.box -text "Timeline" -padding 6
    pack .left.box -fill both -expand 1

    set ui(canvas) [canvas .left.box.c -background white]
    ttk::scrollbar .left.box.vsb -orient vertical -command "$ui(canvas) yview"
    ttk::scrollbar .left.box.hsb -orient horizontal -command "$ui(canvas) xview"
    $ui(canvas) configure -yscrollcommand ".left.box.vsb set" -xscrollcommand ".left.box.hsb set"

    grid $ui(canvas) -row 0 -column 0 -sticky nsew
    grid .left.box.vsb -row 0 -column 1 -sticky ns
    grid .left.box.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .left.box 0 -weight 1
    grid columnconfigure .left.box 0 -weight 1

    bind $ui(canvas) <Button-1> {tl::onCanvasClick [%W canvasx %x] [%W canvasy %y]}
    bind .top.searchE <Return> {tl::renderTimeline}
    bind .top.filterCat <<ComboboxSelected>> {tl::renderTimeline}

    ttk::labelframe .right.detail -text "Dettaglio evento" -padding 10
    pack .right.detail -fill x

    grid columnconfigure .right.detail 1 -weight 1

    foreach {row lbl var} {
        0 "Start:" startV
        1 "End:" endV
        2 "Category:" catV
        3 "Label:" labelV
        4 "Status:" statusV
        5 "Details:" detailsV
    } {
        ttk::label .right.detail.l$row -text $lbl
        ttk::label .right.detail.$var -text "" -wraplength 280 -justify left
        grid .right.detail.l$row -row $row -column 0 -sticky nw -pady 4
        grid .right.detail.$var -row $row -column 1 -sticky w -pady 4
    }

    ttk::labelframe .right.help -text "Formato CSV V1" -padding 10
    pack .right.help -fill x -pady 10

    ttk::label .right.help.txt -justify left -text \
"Colonne attese:
start,end,category,label,status,details

Esempio:
0,12,scenario,Scenario Init,ok,Setup iniziale
10,28,processing,Preprocess,ok,Preprocessing
72,90,validation,Validation,fail,RMSE fuori soglia"

    pack .right.help.txt -anchor w

    ttk::separator .sep -orient horizontal
    pack .sep -fill x

    ttk::label .status -text "Stato: pronto" -padding 6
    pack .status -fill x
}

# --------------------------------------------------
# Main
# --------------------------------------------------
tl::buildUI
tl::loadSampleData