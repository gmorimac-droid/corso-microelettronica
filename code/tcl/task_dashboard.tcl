#!/usr/bin/env wish

package require Tk 8.6
catch {package require json}

# -----------------------------
# Stato applicazione
# -----------------------------
namespace eval app {
    variable tasks {}
    variable nextId 1
    variable filterStatus "Tutti"
    variable simulatedLoad 0

    variable titleVar ""
    variable ownerVar ""
    variable priorityVar "Media"
    variable statusVar "Da fare"
    variable dueVar ""

    variable tree ""
    variable logWidget ""
    variable canvas ""
    variable statusLabel ""
}

# -----------------------------
# Utility
# -----------------------------
proc app::log {msg} {
    variable logWidget
    set ts [clock format [clock seconds] -format "%H:%M:%S"]
    if {[winfo exists $logWidget]} {
        $logWidget insert end "[$ts] $msg\n"
        $logWidget see end
    }
}

proc app::showMessage {title msg {icon info}} {
    tk_messageBox -title $title -message $msg -icon $icon -type ok
}

proc app::addSampleData {} {
    app::addTask "Progettare GUI"   "Alice" "Alta"  "In corso" "2026-04-02" 0
    app::addTask "Scrivere backend" "Bob"   "Alta"  "Da fare"  "2026-04-05" 0
    app::addTask "Test applicazione" "Carla" "Media" "Da fare" "2026-04-08" 0
    app::addTask "Documentazione"   "Diego" "Bassa" "Completata" "2026-03-29" 0
    app::refreshTree
    app::drawStats
    app::log "Dati iniziali caricati."
}

proc app::addTask {title owner priority status due {refresh 1}} {
    variable tasks
    variable nextId

    set task [dict create \
        id $nextId \
        title $title \
        owner $owner \
        priority $priority \
        status $status \
        due $due]

    lappend tasks $task
    incr nextId

    if {$refresh} {
        app::refreshTree
        app::drawStats
    }
}

proc app::clearForm {} {
    variable titleVar ""
    variable ownerVar ""
    variable priorityVar "Media"
    variable statusVar "Da fare"
    variable dueVar ""
}

proc app::validateDate {dateStr} {
    if {$dateStr eq ""} { return 1 }
    return [regexp {^\d{4}-\d{2}-\d{2}$} $dateStr]
}

proc app::submitTask {} {
    variable titleVar
    variable ownerVar
    variable priorityVar
    variable statusVar
    variable dueVar

    if {[string trim $titleVar] eq ""} {
        app::showMessage "Errore" "Il titolo è obbligatorio." error
        return
    }

    if {![app::validateDate $dueVar]} {
        app::showMessage "Errore" "La scadenza deve essere nel formato YYYY-MM-DD." error
        return
    }

    app::addTask $titleVar $ownerVar $priorityVar $statusVar $dueVar
    app::log "Task aggiunta: $titleVar"
    app::clearForm
}

proc app::deleteSelectedTask {} {
    variable tree
    variable tasks

    set sel [$tree selection]
    if {$sel eq ""} {
        app::showMessage "Attenzione" "Seleziona una riga da eliminare." warning
        return
    }

    set item [lindex $sel 0]
    set id [$tree set $item ID]

    set newTasks {}
    foreach t $tasks {
        if {[dict get $t id] != $id} {
            lappend newTasks $t
        }
    }
    set tasks $newTasks

    app::refreshTree
    app::drawStats
    app::log "Task con ID $id eliminata."
}

proc app::refreshTree {} {
    variable tree
    variable tasks
    variable filterStatus

    if {![winfo exists $tree]} { return }

    foreach item [$tree children {}] {
        $tree delete $item
    }

    foreach t $tasks {
        set status [dict get $t status]
        if {$filterStatus ne "Tutti" && $status ne $filterStatus} {
            continue
        }

        $tree insert {} end -values [list \
            [dict get $t id] \
            [dict get $t title] \
            [dict get $t owner] \
            [dict get $t priority] \
            [dict get $t status] \
            [dict get $t due]]
    }
}

proc app::countByStatus {} {
    variable tasks
    array set counts {
        "Da fare" 0
        "In corso" 0
        "Completata" 0
    }

    foreach t $tasks {
        set s [dict get $t status]
        if {[info exists counts($s)]} {
            incr counts($s)
        }
    }
    return [array get counts]
}

proc app::drawStats {} {
    variable canvas
    if {![winfo exists $canvas]} { return }

    $canvas delete all

    array set counts [app::countByStatus]
    set labels {"Da fare" "In corso" "Completata"}

    set width  [winfo width $canvas]
    set height [winfo height $canvas]
    if {$width < 50} { set width 500 }
    if {$height < 50} { set height 250 }

    set max 1
    foreach k $labels {
        if {$counts($k) > $max} { set max $counts($k) }
    }

    set margin 40
    set barWidth 80
    set gap 60
    set x $margin
    set baseY [expr {$height - 40}]

    # assi
    $canvas create line 30 20 30 $baseY -width 2
    $canvas create line 30 $baseY [expr {$width - 20}] $baseY -width 2

    foreach k $labels {
        set value $counts($k)
        set h [expr {($height - 80) * double($value) / $max}]
        set y1 [expr {$baseY - $h}]
        set x2 [expr {$x + $barWidth}]

        $canvas create rectangle $x $y1 $x2 $baseY -outline black -fill lightblue
        $canvas create text [expr {($x + $x2)/2}] [expr {$y1 - 10}] -text $value
        $canvas create text [expr {($x + $x2)/2}] [expr {$baseY + 15}] -text $k

        set x [expr {$x + $barWidth + $gap}]
    }

    $canvas create text [expr {$width / 2}] 10 \
        -text "Statistiche Task" -font "TkHeadingFont"
}

proc app::saveToFile {} {
    variable tasks

    set file [tk_getSaveFile \
        -title "Salva dati" \
        -defaultextension ".json" \
        -filetypes {{"JSON files" {.json}} {"All files" {*}}}]

    if {$file eq ""} { return }

    if {[catch {
        set f [open $file w]
        if {[package provide json] ne ""} {
            puts $f [json::write array {*}[lmap t $tasks {
                json::write object \
                    id       [dict get $t id] \
                    title    [dict get $t title] \
                    owner    [dict get $t owner] \
                    priority [dict get $t priority] \
                    status   [dict get $t status] \
                    due      [dict get $t due]
            }]]
        } else {
            # Fallback semplice: formato Tcl serializzato
            puts $f $tasks
        }
        close $f
    } err]} {
        app::showMessage "Errore" "Salvataggio fallito:\n$err" error
        return
    }

    app::log "Dati salvati in $file"
}

proc app::loadFromFile {} {
    variable tasks
    variable nextId

    set file [tk_getOpenFile \
        -title "Apri dati" \
        -filetypes {{"JSON/Tcl files" {.json .tcldata}} {"All files" {*}}}]

    if {$file eq ""} { return }

    if {[catch {
        set f [open $file r]
        set content [read $f]
        close $f

        # Tentativo semplice: se json disponibile usa json::json2dict
        if {[package provide json] ne "" && [string match {\[*} [string trim $content]]} {
            set parsed [json::json2dict $content]
            set tasks {}
            set maxId 0

            foreach t $parsed {
                # json::json2dict restituisce lista chiave/valore
                set d $t
                lappend tasks [dict create \
                    id       [dict get $d id] \
                    title    [dict get $d title] \
                    owner    [dict get $d owner] \
                    priority [dict get $d priority] \
                    status   [dict get $d status] \
                    due      [dict get $d due]]
                if {[dict get $d id] > $maxId} {
                    set maxId [dict get $d id]
                }
            }
            set nextId [expr {$maxId + 1}]
        } else {
            # fallback su formato Tcl
            set tasks $content
            set maxId 0
            foreach t $tasks {
                if {[dict get $t id] > $maxId} {
                    set maxId [dict get $t id]
                }
            }
            set nextId [expr {$maxId + 1}]
        }
    } err]} {
        app::showMessage "Errore" "Caricamento fallito:\n$err" error
        return
    }

    app::refreshTree
    app::drawStats
    app::log "Dati caricati da $file"
}

proc app::simulateActivity {} {
    variable simulatedLoad
    variable statusLabel
    variable tasks

    incr simulatedLoad
    if {$simulatedLoad > 100} { set simulatedLoad 0 }

    set total [llength $tasks]
    if {[winfo exists $statusLabel]} {
        $statusLabel configure -text "Task: $total   |   Refresh: $simulatedLoad%"
    }

    # Richiama periodicamente sé stessa
    after 1000 app::simulateActivity
}

proc app::onFilterChanged {value} {
    variable filterStatus
    set filterStatus $value
    app::refreshTree
    app::log "Filtro stato impostato a: $value"
}

# -----------------------------
# Costruzione GUI
# -----------------------------
proc app::buildUI {} {
    variable tree
    variable logWidget
    variable canvas
    variable statusLabel
    variable titleVar
    variable ownerVar
    variable priorityVar
    variable statusVar
    variable dueVar

    wm title . "Task Dashboard - Esempio Tcl/Tk"
    wm geometry . 1000x650
    wm minsize . 900 550

    ttk::style theme use clam

    # Menu
    menu .menubar
    . configure -menu .menubar

    menu .menubar.file -tearoff 0
    .menubar add cascade -label "File" -menu .menubar.file
    .menubar.file add command -label "Apri..." -command app::loadFromFile
    .menubar.file add command -label "Salva..." -command app::saveToFile
    .menubar.file add separator
    .menubar.file add command -label "Esci" -command exit

    menu .menubar.help -tearoff 0
    .menubar add cascade -label "Help" -menu .menubar.help
    .menubar.help add command -label "Informazioni" \
        -command {app::showMessage "Informazioni" "Esempio completo Tcl/Tk\nTask Dashboard"}

    # Layout principale
    ttk::frame .main -padding 8
    pack .main -fill both -expand 1

    ttk::panedwindow .main.pw -orient horizontal
    pack .main.pw -fill both -expand 1

    ttk::frame .left -padding 6
    ttk::frame .right -padding 6

    .main.pw add .left -weight 1
    .main.pw add .right -weight 3

    # -------------------------
    # Pannello sinistro: form
    # -------------------------
    ttk::labelframe .left.form -text "Nuova Task" -padding 10
    pack .left.form -fill x

    grid columnconfigure .left.form 1 -weight 1

    ttk::label .left.form.l1 -text "Titolo:"
    ttk::entry .left.form.e1 -textvariable app::titleVar

    ttk::label .left.form.l2 -text "Responsabile:"
    ttk::entry .left.form.e2 -textvariable app::ownerVar

    ttk::label .left.form.l3 -text "Priorità:"
    ttk::combobox .left.form.c1 -textvariable app::priorityVar \
        -values {"Alta" "Media" "Bassa"} -state readonly

    ttk::label .left.form.l4 -text "Stato:"
    ttk::combobox .left.form.c2 -textvariable app::statusVar \
        -values {"Da fare" "In corso" "Completata"} -state readonly

    ttk::label .left.form.l5 -text "Scadenza:"
    ttk::entry .left.form.e3 -textvariable app::dueVar
    ttk::label .left.form.l6 -text "Formato: YYYY-MM-DD"

    ttk::button .left.form.b1 -text "Aggiungi" -command app::submitTask
    ttk::button .left.form.b2 -text "Pulisci" -command app::clearForm

    grid .left.form.l1  -row 0 -column 0 -sticky w -pady 3
    grid .left.form.e1  -row 0 -column 1 -sticky ew -pady 3
    grid .left.form.l2  -row 1 -column 0 -sticky w -pady 3
    grid .left.form.e2  -row 1 -column 1 -sticky ew -pady 3
    grid .left.form.l3  -row 2 -column 0 -sticky w -pady 3
    grid .left.form.c1  -row 2 -column 1 -sticky ew -pady 3
    grid .left.form.l4  -row 3 -column 0 -sticky w -pady 3
    grid .left.form.c2  -row 3 -column 1 -sticky ew -pady 3
    grid .left.form.l5  -row 4 -column 0 -sticky w -pady 3
    grid .left.form.e3  -row 4 -column 1 -sticky ew -pady 3
    grid .left.form.l6  -row 5 -column 1 -sticky w
    grid .left.form.b1  -row 6 -column 0 -sticky ew -pady 8
    grid .left.form.b2  -row 6 -column 1 -sticky ew -pady 8

    ttk::labelframe .left.actions -text "Azioni" -padding 10
    pack .left.actions -fill x -pady 10

    ttk::button .left.actions.del -text "Elimina selezionata" -command app::deleteSelectedTask
    ttk::button .left.actions.save -text "Salva dati" -command app::saveToFile
    ttk::button .left.actions.load -text "Carica dati" -command app::loadFromFile

    pack .left.actions.del  -fill x -pady 3
    pack .left.actions.save -fill x -pady 3
    pack .left.actions.load -fill x -pady 3

    # -------------------------
    # Pannello destro: notebook
    # -------------------------
    ttk::notebook .right.nb
    pack .right.nb -fill both -expand 1

    ttk::frame .right.tabTasks -padding 6
    ttk::frame .right.tabStats -padding 6
    ttk::frame .right.tabLog   -padding 6

    .right.nb add .right.tabTasks -text "Task"
    .right.nb add .right.tabStats -text "Statistiche"
    .right.nb add .right.tabLog   -text "Log"

    # Tab Task
    ttk::frame .right.tabTasks.top
    pack .right.tabTasks.top -fill x

    ttk::label .right.tabTasks.top.fl -text "Filtro stato:"
    ttk::combobox .right.tabTasks.top.fc \
        -values {"Tutti" "Da fare" "In corso" "Completata"} \
        -state readonly
    .right.tabTasks.top.fc set "Tutti"
    bind .right.tabTasks.top.fc <<ComboboxSelected>> {
        app::onFilterChanged [%W get]
    }

    pack .right.tabTasks.top.fl -side left -padx 2
    pack .right.tabTasks.top.fc -side left -padx 6

    ttk::frame .right.tabTasks.tableFrame
    pack .right.tabTasks.tableFrame -fill both -expand 1 -pady 8

    ttk::scrollbar .right.tabTasks.vsb -orient vertical
    ttk::scrollbar .right.tabTasks.hsb -orient horizontal

    set tree [ttk::treeview .right.tabTasks.tableFrame.tree \
        -columns {ID Titolo Owner Priorita Stato Scadenza} \
        -show headings \
        -yscrollcommand ".right.tabTasks.vsb set" \
        -xscrollcommand ".right.tabTasks.hsb set"]

    .right.tabTasks.vsb configure -command "$tree yview"
    .right.tabTasks.hsb configure -command "$tree xview"

    foreach col {ID Titolo Owner Priorita Stato Scadenza} {
        $tree heading $col -text $col
    }

    $tree column ID -width 50 -anchor center
    $tree column Titolo -width 240
    $tree column Owner -width 120
    $tree column Priorita -width 100 -anchor center
    $tree column Stato -width 110 -anchor center
    $tree column Scadenza -width 120 -anchor center

    grid $tree -row 0 -column 0 -sticky nsew
    grid .right.tabTasks.vsb -row 0 -column 1 -sticky ns
    grid .right.tabTasks.hsb -row 1 -column 0 -sticky ew

    grid rowconfigure .right.tabTasks.tableFrame 0 -weight 1
    grid columnconfigure .right.tabTasks.tableFrame 0 -weight 1

    pack .right.tabTasks.tableFrame -fill both -expand 1

    # Tab Statistiche
    set canvas [canvas .right.tabStats.c -background white -height 280]
    pack $canvas -fill both -expand 1

    bind $canvas <Configure> {app::drawStats}

    # Tab Log
    set logWidget [text .right.tabLog.txt -wrap word -height 10]
    ttk::scrollbar .right.tabLog.sb -orient vertical -command "$logWidget yview"
    $logWidget configure -yscrollcommand ".right.tabLog.sb set"

    pack .right.tabLog.sb -side right -fill y
    pack $logWidget -side left -fill both -expand 1

    # Status bar
    ttk::separator .sep -orient horizontal
    pack .sep -fill x

    set statusLabel [ttk::label .status -text "Pronto" -padding 6]
    pack .status -fill x
}

# -----------------------------
# Avvio
# -----------------------------
app::buildUI
app::addSampleData
app::simulateActivity