#!/usr/bin/env wish

package require Tk 8.6

namespace eval loga {
    variable currentFile ""
    variable rawLines {}
    variable visibleLines {}
    variable matchIndices {}

    variable ui

    variable filterError 1
    variable filterWarn 1
    variable filterInfo 1
    variable filterDebug 1
    variable onlyMatching 0
    variable searchText ""

    variable countError 0
    variable countWarn 0
    variable countInfo 0
    variable countDebug 0
    variable countOther 0
}

# --------------------------------------------------
# Utility
# --------------------------------------------------
proc loga::classifyLine {line} {
    set u [string toupper $line]

    if {[string match "*ERROR*" $u] || [string match "*FATAL*" $u]} {
        return error
    }
    if {[string match "*WARN*" $u] || [string match "*WARNING*" $u]} {
        return warn
    }
    if {[string match "*DEBUG*" $u] || [string match "*TRACE*" $u]} {
        return debug
    }
    if {[string match "*INFO*" $u]} {
        return info
    }
    return other
}

proc loga::lineMatchesSearch {line pattern} {
    if {[string trim $pattern] eq ""} {
        return 1
    }
    return [expr {[string first [string tolower $pattern] [string tolower $line]] >= 0}]
}

proc loga::severityEnabled {sev} {
    variable filterError
    variable filterWarn
    variable filterInfo
    variable filterDebug

    switch -- $sev {
        error { return $filterError }
        warn  { return $filterWarn }
        info  { return $filterInfo }
        debug { return $filterDebug }
        other { return 1 }
    }
    return 1
}

proc loga::logStatus {msg} {
    .status configure -text "Stato: $msg"
}

# --------------------------------------------------
# File I/O
# --------------------------------------------------
proc loga::openLogFile {} {
    variable currentFile
    variable rawLines

    set f [tk_getOpenFile \
        -title "Apri file di log" \
        -filetypes {{"Log files" {.log .txt .out}} {"All files" {*}}}]
    if {$f eq ""} { return }

    if {[catch {
        set ch [open $f r]
        set content [read $ch]
        close $ch
    } err]} {
        tk_messageBox -icon error -title "Errore" -message "Impossibile aprire il log:\n$err"
        return
    }

    set currentFile $f
    set rawLines [split $content "\n"]
    wm title . "Log Analyzer - [file tail $currentFile]"
    loga::applyFilters
    loga::logStatus "log caricato"
}

proc loga::reloadLogFile {} {
    variable currentFile
    variable rawLines

    if {$currentFile eq ""} {
        tk_messageBox -icon info -title "Reload" -message "Nessun file aperto."
        return
    }

    if {[catch {
        set ch [open $currentFile r]
        set content [read $ch]
        close $ch
    } err]} {
        tk_messageBox -icon error -title "Errore" -message "Impossibile ricaricare il log:\n$err"
        return
    }

    set rawLines [split $content "\n"]
    loga::applyFilters
    loga::logStatus "log ricaricato"
}

proc loga::saveFilteredLog {} {
    variable visibleLines

    set f [tk_getSaveFile \
        -title "Salva log filtrato" \
        -defaultextension ".log" \
        -filetypes {{"Log files" {.log .txt}} {"All files" {*}}}]
    if {$f eq ""} { return }

    if {[catch {
        set ch [open $f w]
        puts -nonewline $ch [join $visibleLines "\n"]
        close $ch
    } err]} {
        tk_messageBox -icon error -title "Errore" -message "Impossibile salvare il log filtrato:\n$err"
        return
    }

    loga::logStatus "log filtrato salvato"
}

# --------------------------------------------------
# Stats + filtering
# --------------------------------------------------
proc loga::recomputeStats {} {
    variable visibleLines
    variable countError
    variable countWarn
    variable countInfo
    variable countDebug
    variable countOther

    set countError 0
    set countWarn 0
    set countInfo 0
    set countDebug 0
    set countOther 0

    foreach line $visibleLines {
        switch -- [loga::classifyLine $line] {
            error { incr countError }
            warn  { incr countWarn }
            info  { incr countInfo }
            debug { incr countDebug }
            other { incr countOther }
        }
    }

    .stats configure -text "ERROR=$countError   WARN=$countWarn   INFO=$countInfo   DEBUG=$countDebug   OTHER=$countOther"
}

proc loga::applyFilters {} {
    variable rawLines
    variable visibleLines
    variable searchText
    variable onlyMatching
    variable matchIndices

    set visibleLines {}
    set matchIndices {}

    set idx 0
    foreach line $rawLines {
        set sev [loga::classifyLine $line]
        set sevOk [loga::severityEnabled $sev]
        set txtOk [loga::lineMatchesSearch $line $searchText]

        if {$onlyMatching} {
            if {$sevOk && $txtOk} {
                lappend visibleLines $line
                if {[string trim $searchText] ne ""} {
                    lappend matchIndices [llength $visibleLines]
                }
            }
        } else {
            if {$sevOk} {
                lappend visibleLines $line
                if {$txtOk && [string trim $searchText] ne ""} {
                    lappend matchIndices [llength $visibleLines]
                }
            }
        }
        incr idx
    }

    loga::renderVisibleLines
    loga::refreshCriticalList
    loga::recomputeStats
}

# --------------------------------------------------
# Viewer rendering
# --------------------------------------------------
proc loga::configureTags {} {
    variable ui
    $ui(viewer) tag configure error -foreground red
    $ui(viewer) tag configure warn -foreground darkorange3
    $ui(viewer) tag configure info -foreground darkgreen
    $ui(viewer) tag configure debug -foreground blue
    $ui(viewer) tag configure other -foreground black
    $ui(viewer) tag configure hit -background yellow
}

proc loga::renderVisibleLines {} {
    variable ui
    variable visibleLines
    variable searchText

    $ui(viewer) configure -state normal
    $ui(viewer) delete 1.0 end

    set lineNo 1
    foreach line $visibleLines {
        set sev [loga::classifyLine $line]
        $ui(viewer) insert end $line $sev
        $ui(viewer) insert end "\n"

        if {[string trim $searchText] ne ""} {
            set start "$lineNo.0"
            set end "$lineNo.end"
            set pos [$ui(viewer) search -nocase $searchText $start $end]
            while {$pos ne ""} {
                set posEnd "$pos + [string length $searchText] chars"
                $ui(viewer) tag add hit $pos $posEnd
                set pos [$ui(viewer) search -nocase $searchText $posEnd $end]
            }
        }
        incr lineNo
    }

    $ui(viewer) configure -state disabled
}

proc loga::refreshCriticalList {} {
    variable ui
    variable visibleLines

    $ui(criticalList) delete 0 end

    set lineNo 1
    foreach line $visibleLines {
        set sev [loga::classifyLine $line]
        if {$sev eq "error" || $sev eq "warn"} {
            set short $line
            if {[string length $short] > 120} {
                set short "[string range $short 0 116]..."
            }
            $ui(criticalList) insert end "$lineNo | $short"
        }
        incr lineNo
    }
}

proc loga::jumpToCritical {} {
    variable ui

    set sel [$ui(criticalList) curselection]
    if {$sel eq ""} { return }

    set item [$ui(criticalList) get [lindex $sel 0]]
    if {[regexp {^([0-9]+)\s+\|} $item -> lineNo]} {
        $ui(viewer) see "${lineNo}.0"
        $ui(viewer) tag remove sel 1.0 end
        $ui(viewer) tag add sel "${lineNo}.0" "${lineNo}.end"
    }
}

proc loga::findNextHit {} {
    variable ui
    variable searchText

    if {[string trim $searchText] eq ""} {
        return
    }

    set cur [$ui(viewer) index insert]
    set pos [$ui(viewer) search -nocase $searchText "$cur + 1 chars" end]
    if {$pos eq ""} {
        set pos [$ui(viewer) search -nocase $searchText 1.0 end]
    }

    if {$pos ne ""} {
        set endPos "$pos + [string length $searchText] chars"
        $ui(viewer) see $pos
        $ui(viewer) tag remove sel 1.0 end
        $ui(viewer) tag add sel $pos $endPos
        $ui(viewer) mark set insert $pos
        focus $ui(viewer)
    }
}

# --------------------------------------------------
# Sample log
# --------------------------------------------------
proc loga::loadSampleLog {} {
    variable rawLines
    set rawLines {
        {[12:00:01] INFO loading radar configuration}
        {[12:00:02] INFO opening input data file}
        {[12:00:03] WARN antenna calibration file missing, using default}
        {[12:00:04] INFO preprocessing started}
        {[12:00:05] DEBUG FFT block size = 4096}
        {[12:00:06] DEBUG CFAR window = 24}
        {[12:00:07] INFO detector initialized}
        {[12:00:08] WARN noisy sector detected at azimuth 132}
        {[12:00:09] ERROR checksum mismatch on block 17}
        {[12:00:10] INFO retrying block acquisition}
        {[12:00:11] INFO block acquisition recovered}
        {[12:00:12] ERROR tracker divergence on target id 3}
        {[12:00:13] INFO run completed with degraded quality}
    }
    set ::loga::currentFile ""
    wm title . "Log Analyzer - sample log"
    loga::applyFilters
    loga::logStatus "sample log caricato"
}

# --------------------------------------------------
# UI
# --------------------------------------------------
proc loga::buildUI {} {
    variable ui

    wm title . "Log Analyzer"
    wm geometry . 1250x820
    wm minsize . 1000 680
    ttk::style theme use clam

    ttk::frame .toolbar -padding 6
    pack .toolbar -fill x

    ttk::button .toolbar.open   -text "Apri log" -command loga::openLogFile
    ttk::button .toolbar.reload -text "Ricarica" -command loga::reloadLogFile
    ttk::button .toolbar.save   -text "Salva filtrato" -command loga::saveFilteredLog
    ttk::button .toolbar.sample -text "Sample" -command loga::loadSampleLog

    ttk::label .toolbar.searchL -text "Cerca:"
    ttk::entry .toolbar.searchE -textvariable loga::searchText
    ttk::button .toolbar.find   -text "Trova" -command loga::findNextHit
    ttk::button .toolbar.apply  -text "Applica filtri" -command loga::applyFilters

    pack .toolbar.open .toolbar.reload .toolbar.save .toolbar.sample -side left -padx 4
    pack .toolbar.apply .toolbar.find -side right -padx 4
    pack .toolbar.searchE -side right -padx 4
    pack .toolbar.searchL -side right -padx 4

    ttk::frame .filters -padding 6
    pack .filters -fill x

    ttk::checkbutton .filters.err  -text "ERROR" -variable loga::filterError
    ttk::checkbutton .filters.warn -text "WARN"  -variable loga::filterWarn
    ttk::checkbutton .filters.info -text "INFO"  -variable loga::filterInfo
    ttk::checkbutton .filters.dbg  -text "DEBUG" -variable loga::filterDebug
    ttk::checkbutton .filters.match -text "Solo matching" -variable loga::onlyMatching

    pack .filters.err .filters.warn .filters.info .filters.dbg .filters.match -side left -padx 6

    ttk::panedwindow .pw -orient horizontal
    pack .pw -fill both -expand 1

    ttk::frame .left -padding 6
    ttk::frame .right -padding 6
    .pw add .left -weight 1
    .pw add .right -weight 4

    ttk::labelframe .left.box -text "Eventi critici" -padding 6
    pack .left.box -fill both -expand 1

    set ui(criticalList) [listbox .left.box.lb -exportselection 0]
    ttk::scrollbar .left.box.sb -orient vertical -command "$ui(criticalList) yview"
    $ui(criticalList) configure -yscrollcommand ".left.box.sb set"

    grid $ui(criticalList) -row 0 -column 0 -sticky nsew
    grid .left.box.sb -row 0 -column 1 -sticky ns
    grid rowconfigure .left.box 0 -weight 1
    grid columnconfigure .left.box 0 -weight 1

    ttk::labelframe .right.box -text "Viewer log" -padding 6
    pack .right.box -fill both -expand 1

    set ui(viewer) [text .right.box.txt -wrap none]
    ttk::scrollbar .right.box.vsb -orient vertical -command "$ui(viewer) yview"
    ttk::scrollbar .right.box.hsb -orient horizontal -command "$ui(viewer) xview"
    $ui(viewer) configure -yscrollcommand ".right.box.vsb set" -xscrollcommand ".right.box.hsb set" -state disabled

    grid $ui(viewer) -row 0 -column 0 -sticky nsew
    grid .right.box.vsb -row 0 -column 1 -sticky ns
    grid .right.box.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .right.box 0 -weight 1
    grid columnconfigure .right.box 0 -weight 1

    bind $ui(criticalList) <<ListboxSelect>> loga::jumpToCritical
    bind .toolbar.searchE <Return> {loga::applyFilters}

    ttk::separator .sep1 -orient horizontal
    pack .sep1 -fill x

    ttk::label .stats -text "ERROR=0   WARN=0   INFO=0   DEBUG=0   OTHER=0" -padding 6
    pack .stats -fill x

    ttk::separator .sep2 -orient horizontal
    pack .sep2 -fill x

    ttk::label .status -text "Stato: pronto" -padding 6
    pack .status -fill x
}

# --------------------------------------------------
# Main
# --------------------------------------------------
loga::buildUI
loga::configureTags
loga::loadSampleLog