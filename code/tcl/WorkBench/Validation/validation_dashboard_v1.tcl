#!/usr/bin/env wish

package require Tk 8.6

namespace eval vd {
    variable metricsFile ""
    variable baselineFile ""

    variable metricsData {}
    variable baselineData {}

    variable ui

    variable passCount 0
    variable warnCount 0
    variable failCount 0
}

# --------------------------------------------------
# Utility
# --------------------------------------------------
proc vd::logStatus {msg} {
    .status configure -text "Stato: $msg"
}

proc vd::toNumber {x} {
    if {[string trim $x] eq ""} {
        return ""
    }
    if {[string is double -strict $x]} {
        return $x
    }
    return ""
}

proc vd::safeDelta {a b} {
    set na [vd::toNumber $a]
    set nb [vd::toNumber $b]
    if {$na eq "" || $nb eq ""} {
        return ""
    }
    return [format "%.6g" [expr {$na - $nb}]]
}

proc vd::overallStatus {} {
    variable failCount
    variable warnCount

    if {$failCount > 0} {
        return "FAIL"
    }
    if {$warnCount > 0} {
        return "WARN"
    }
    return "PASS"
}

# --------------------------------------------------
# CSV parsing
# --------------------------------------------------
proc vd::parseCsvLine {line} {
    # parser semplice per CSV senza quoting complesso
    return [split $line ","]
}

proc vd::loadCsvAsDicts {path} {
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

    set header [vd::parseCsvLine [lindex $lines 0]]
    set rows {}

    foreach line [lrange $lines 1 end] {
        set cols [vd::parseCsvLine $line]
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

proc vd::baselineMap {} {
    variable baselineData
    set m [dict create]
    foreach row $baselineData {
        if {[dict exists $row metric] && [dict exists $row value]} {
            dict set m [dict get $row metric] [dict get $row value]
        }
    }
    return $m
}

# --------------------------------------------------
# Evaluation
# --------------------------------------------------
proc vd::evaluateMetricRow {row baselineMap} {
    set metric [expr {[dict exists $row metric] ? [dict get $row metric] : ""}]
    set value  [expr {[dict exists $row value] ? [dict get $row value] : ""}]
    set minVal [expr {[dict exists $row min] ? [dict get $row min] : ""}]
    set maxVal [expr {[dict exists $row max] ? [dict get $row max] : ""}]

    set baseline ""
    if {[dict exists $baselineMap $metric]} {
        set baseline [dict get $baselineMap $metric]
    }

    set status "WARN"
    set numValue [vd::toNumber $value]
    set numMin   [vd::toNumber $minVal]
    set numMax   [vd::toNumber $maxVal]

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
            if {$ok} {
                set status "PASS"
            } else {
                set status "FAIL"
            }
        }
    }

    set delta [vd::safeDelta $value $baseline]

    return [dict create \
        metric $metric \
        value $value \
        baseline $baseline \
        delta $delta \
        min $minVal \
        max $maxVal \
        status $status]
}

# --------------------------------------------------
# Table rendering
# --------------------------------------------------
proc vd::clearTable {} {
    variable ui
    set tree $ui(tree)
    foreach item [$tree children {}] {
        $tree delete $item
    }
}

proc vd::refreshSummary {} {
    variable passCount
    variable warnCount
    variable failCount
    variable ui

    set overall [vd::overallStatus]
    $ui(summary) configure -text "PASS=$passCount   WARN=$warnCount   FAIL=$failCount   =>   $overall"
}

proc vd::refreshTable {} {
    variable metricsData
    variable ui
    variable passCount
    variable warnCount
    variable failCount

    vd::clearTable

    set passCount 0
    set warnCount 0
    set failCount 0

    set baselineMap [vd::baselineMap]
    set tree $ui(tree)

    foreach row $metricsData {
        set evalRow [vd::evaluateMetricRow $row $baselineMap]

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

    vd::refreshSummary
    vd::logStatus "dashboard aggiornato"
}

# --------------------------------------------------
# Detail panel
# --------------------------------------------------
proc vd::clearDetail {} {
    .right.detail.metricV configure -text ""
    .right.detail.valueV configure -text ""
    .right.detail.baseV configure -text ""
    .right.detail.deltaV configure -text ""
    .right.detail.minV configure -text ""
    .right.detail.maxV configure -text ""
    .right.detail.statusV configure -text ""
}

proc vd::onTreeSelect {} {
    variable ui
    set tree $ui(tree)
    set sel [$tree selection]
    if {$sel eq ""} {
        vd::clearDetail
        return
    }

    set item [lindex $sel 0]

    .right.detail.metricV configure -text [$tree set $item 0]
    .right.detail.valueV  configure -text [$tree set $item 1]
    .right.detail.baseV   configure -text [$tree set $item 2]
    .right.detail.deltaV  configure -text [$tree set $item 3]
    .right.detail.minV    configure -text [$tree set $item 4]
    .right.detail.maxV    configure -text [$tree set $item 5]
    .right.detail.statusV configure -text [$tree set $item 6]
}

# --------------------------------------------------
# File actions
# --------------------------------------------------
proc vd::openMetricsFile {} {
    variable metricsFile
    variable metricsData

    set f [tk_getOpenFile \
        -title "Apri file metriche" \
        -filetypes {{"CSV files" {.csv}} {"All files" {*}}}]
    if {$f eq ""} { return }

    if {[catch {
        set metricsData [vd::loadCsvAsDicts $f]
        set metricsFile $f
    } err]} {
        tk_messageBox -icon error -title "Errore" -message $err
        return
    }

    .top.metricsEntry delete 0 end
    .top.metricsEntry insert 0 $f
    vd::refreshTable
}

proc vd::openBaselineFile {} {
    variable baselineFile
    variable baselineData

    set f [tk_getOpenFile \
        -title "Apri file baseline" \
        -filetypes {{"CSV files" {.csv}} {"All files" {*}}}]
    if {$f eq ""} { return }

    if {[catch {
        set baselineData [vd::loadCsvAsDicts $f]
        set baselineFile $f
    } err]} {
        tk_messageBox -icon error -title "Errore" -message $err
        return
    }

    .top.baseEntry delete 0 end
    .top.baseEntry insert 0 $f
    vd::refreshTable
}

proc vd::reloadFiles {} {
    variable metricsFile
    variable baselineFile
    variable metricsData
    variable baselineData

    if {$metricsFile eq ""} {
        tk_messageBox -icon info -title "Reload" -message "Nessun file metriche caricato."
        return
    }

    if {[catch {
        set metricsData [vd::loadCsvAsDicts $metricsFile]
        if {$baselineFile ne ""} {
            set baselineData [vd::loadCsvAsDicts $baselineFile]
        }
    } err]} {
        tk_messageBox -icon error -title "Errore" -message $err
        return
    }

    vd::refreshTable
}

# --------------------------------------------------
# Sample data
# --------------------------------------------------
proc vd::loadSampleData {} {
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

    .top.metricsEntry delete 0 end
    .top.baseEntry delete 0 end

    vd::refreshTable
    vd::logStatus "sample data caricati"
}

# --------------------------------------------------
# UI
# --------------------------------------------------
proc vd::buildUI {} {
    variable ui

    wm title . "Validation Dashboard"
    wm geometry . 1350x860
    wm minsize . 1080 720
    ttk::style theme use clam

    ttk::frame .top -padding 6
    pack .top -fill x

    ttk::button .top.openMetrics -text "Apri metriche" -command vd::openMetricsFile
    ttk::button .top.openBase    -text "Apri baseline" -command vd::openBaselineFile
    ttk::button .top.reload      -text "Ricarica" -command vd::reloadFiles
    ttk::button .top.sample      -text "Sample" -command vd::loadSampleData

    ttk::label .top.metricsL -text "Metriche:"
    entry .top.metricsEntry
    ttk::label .top.baseL -text "Baseline:"
    entry .top.baseEntry

    pack .top.openMetrics .top.openBase .top.reload .top.sample -side left -padx 4
    pack .top.baseEntry -side right -fill x -expand 1 -padx 3
    pack .top.baseL -side right -padx 3
    pack .top.metricsEntry -side right -fill x -expand 1 -padx 3
    pack .top.metricsL -side right -padx 3

    ttk::panedwindow .pw -orient horizontal
    pack .pw -fill both -expand 1

    ttk::frame .left -padding 6
    ttk::frame .right -padding 6
    .pw add .left -weight 4
    .pw add .right -weight 2

    # Left: table
    ttk::labelframe .left.box -text "Metriche" -padding 6
    pack .left.box -fill both -expand 1

    set ui(tree) [ttk::treeview .left.box.tree \
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

    bind $ui(tree) <<TreeviewSelect>> vd::onTreeSelect

    $ui(tree) tag configure pass -foreground darkgreen
    $ui(tree) tag configure warn -foreground darkorange3
    $ui(tree) tag configure fail -foreground red

    # Right: detail
    ttk::labelframe .right.detail -text "Dettaglio metrica" -padding 10
    pack .right.detail -fill x

    grid columnconfigure .right.detail 1 -weight 1

    foreach {row lbl var} {
        0 "Metric:"   metricV
        1 "Value:"    valueV
        2 "Baseline:" baseV
        3 "Delta:"    deltaV
        4 "Min:"      minV
        5 "Max:"      maxV
        6 "Status:"   statusV
    } {
        ttk::label .right.detail.l$row -text $lbl
        ttk::label .right.detail.$var -text "" -wraplength 320 -justify left
        grid .right.detail.l$row -row $row -column 0 -sticky w -pady 4
        grid .right.detail.$var  -row $row -column 1 -sticky w -pady 4
    }

    ttk::labelframe .right.help -text "Regole V1" -padding 10
    pack .right.help -fill x -pady 10

    ttk::label .right.help.txt -justify left -text \
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

    pack .right.help.txt -anchor w

    ttk::separator .sep1 -orient horizontal
    pack .sep1 -fill x

    set ui(summary) [ttk::label .summary -text "PASS=0   WARN=0   FAIL=0   =>   PASS" -padding 6]
    pack .summary -fill x

    ttk::separator .sep2 -orient horizontal
    pack .sep2 -fill x

    ttk::label .status -text "Stato: pronto" -padding 6
    pack .status -fill x
}

# --------------------------------------------------
# Main
# --------------------------------------------------
vd::buildUI
vd::loadSampleData