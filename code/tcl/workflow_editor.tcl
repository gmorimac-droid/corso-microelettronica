#!/usr/bin/env wish

package require Tk 8.6

namespace eval wf {
    variable canvas
    variable statusLabel
    variable propNameVar ""
    variable selectedNode ""
    variable mode "select"       ;# select | add | connect
    variable nodes               ;# array: id -> dict
    variable edges {}            ;# list of dict {from X to Y lineId Z}
    variable nextNodeId 1
    variable connectFrom ""
    variable dragNode ""
    variable dragLastX 0
    variable dragLastY 0
    variable nodeWidth 120
    variable nodeHeight 50
}

# -----------------------------
# Utility
# -----------------------------
proc wf::setStatus {msg} {
    variable statusLabel
    if {[winfo exists $statusLabel]} {
        $statusLabel configure -text $msg
    }
}

proc wf::nodeTag {id} {
    return "node_$id"
}

proc wf::nodeTextTag {id} {
    return "node_text_$id"
}

proc wf::nodeRectTag {id} {
    return "node_rect_$id"
}

proc wf::edgeTag {from to} {
    return "edge_${from}_${to}"
}

proc wf::centerOfNode {id} {
    variable nodes
    set x [dict get $nodes($id) x]
    set y [dict get $nodes($id) y]
    return [list $x $y]
}

proc wf::getNodeAt {x y} {
    variable canvas
    set items [$canvas find overlapping $x $y $x $y]
    foreach item [lreverse $items] {
        foreach tag [$canvas gettags $item] {
            if {[regexp {^node_([0-9]+)$} $tag -> id]} {
                return $id
            }
        }
    }
    return ""
}

proc wf::clearSelection {} {
    variable selectedNode
    variable nodes
    variable canvas

    if {$selectedNode ne "" && [info exists nodes($selectedNode)]} {
        set rectId [dict get $nodes($selectedNode) rect]
        $canvas itemconfigure $rectId -width 2 -outline black
    }
    set selectedNode ""
}

proc wf::selectNode {id} {
    variable selectedNode
    variable nodes
    variable canvas
    variable propNameVar

    wf::clearSelection
    if {$id eq ""} return
    set selectedNode $id
    set rectId [dict get $nodes($id) rect]
    $canvas itemconfigure $rectId -width 3 -outline blue
    set propNameVar [dict get $nodes($id) name]
    wf::setStatus "Nodo selezionato: [dict get $nodes($id) name]"
}

# -----------------------------
# Nodo
# -----------------------------
proc wf::createNode {x y {name ""}} {
    variable canvas
    variable nodes
    variable nextNodeId
    variable nodeWidth
    variable nodeHeight

    set id $nextNodeId
    incr nextNodeId

    if {$name eq ""} {
        set name "Step $id"
    }

    set halfW [expr {$nodeWidth / 2}]
    set halfH [expr {$nodeHeight / 2}]
    set x1 [expr {$x - $halfW}]
    set y1 [expr {$y - $halfH}]
    set x2 [expr {$x + $halfW}]
    set y2 [expr {$y + $halfH}]

    set rect [$canvas create rectangle $x1 $y1 $x2 $y2 \
        -fill "#e8f0ff" -outline black -width 2 \
        -tags [list [wf::nodeTag $id] [wf::nodeRectTag $id]]]

    set text [$canvas create text $x $y \
        -text $name \
        -font "TkDefaultFont 10" \
        -tags [list [wf::nodeTag $id] [wf::nodeTextTag $id]]]

    set nodes($id) [dict create \
        id $id \
        name $name \
        x $x \
        y $y \
        rect $rect \
        text $text]

    wf::selectNode $id
    wf::setStatus "Creato nodo $name"
    return $id
}

proc wf::renameSelectedNode {} {
    variable selectedNode
    variable nodes
    variable propNameVar
    variable canvas

    if {$selectedNode eq ""} {
        wf::setStatus "Nessun nodo selezionato"
        return
    }

    set propNameVar [string trim $propNameVar]
    if {$propNameVar eq ""} {
        set propNameVar "Step $selectedNode"
    }

    dict set nodes($selectedNode) name $propNameVar
    set textId [dict get $nodes($selectedNode) text]
    $canvas itemconfigure $textId -text $propNameVar
    wf::setStatus "Nodo rinominato in: $propNameVar"
}

proc wf::deleteSelectedNode {} {
    variable selectedNode
    variable nodes
    variable canvas
    variable edges

    if {$selectedNode eq ""} {
        wf::setStatus "Nessun nodo selezionato"
        return
    }

    set id $selectedNode

    $canvas delete [dict get $nodes($id) rect]
    $canvas delete [dict get $nodes($id) text]
    unset nodes($id)

    set newEdges {}
    foreach e $edges {
        set from [dict get $e from]
        set to   [dict get $e to]
        set lineId [dict get $e lineId]
        if {$from == $id || $to == $id} {
            $canvas delete $lineId
        } else {
            lappend newEdges $e
        }
    }
    set edges $newEdges

    set selectedNode ""
    set ::wf::propNameVar ""
    wf::setStatus "Nodo eliminato"
}

# -----------------------------
# Edge
# -----------------------------
proc wf::edgeExists {from to} {
    variable edges
    foreach e $edges {
        if {[dict get $e from] == $from && [dict get $e to] == $to} {
            return 1
        }
    }
    return 0
}

proc wf::createEdge {from to} {
    variable edges
    variable canvas

    if {$from eq "" || $to eq "" || $from == $to} return
    if {[wf::edgeExists $from $to]} {
        wf::setStatus "Collegamento già presente"
        return
    }

    lassign [wf::centerOfNode $from] x1 y1
    lassign [wf::centerOfNode $to]   x2 y2

    set lineId [$canvas create line $x1 $y1 $x2 $y2 \
        -arrow last -width 2 -fill "#444444" \
        -tags [list [wf::edgeTag $from $to]]]

    $canvas lower $lineId

    lappend edges [dict create from $from to $to lineId $lineId]
    wf::setStatus "Creato collegamento $from → $to"
}

proc wf::redrawEdgesForNode {nodeId} {
    variable edges
    variable canvas

    set newEdges {}
    foreach e $edges {
        set from [dict get $e from]
        set to   [dict get $e to]
        set lineId [dict get $e lineId]

        if {$from == $nodeId || $to == $nodeId} {
            lassign [wf::centerOfNode $from] x1 y1
            lassign [wf::centerOfNode $to]   x2 y2
            $canvas coords $lineId $x1 $y1 $x2 $y2
        }
        lappend newEdges $e
    }
    set edges $newEdges
}

# -----------------------------
# Drag & click
# -----------------------------
proc wf::canvasClick {x y} {
    variable mode
    variable connectFrom

    set id [wf::getNodeAt $x $y]

    switch -- $mode {
        add {
            wf::createNode $x $y
            set ::wf::mode "select"
            wf::updateModeUI
        }
        connect {
            if {$id eq ""} {
                wf::setStatus "Clicca due nodi per collegarli"
                return
            }
            if {$connectFrom eq ""} {
                set connectFrom $id
                wf::selectNode $id
                wf::setStatus "Origine selezionata. Ora scegli il nodo destinazione."
            } else {
                wf::createEdge $connectFrom $id
                set connectFrom ""
                set ::wf::mode "select"
                wf::updateModeUI
            }
        }
        default {
            if {$id ne ""} {
                wf::selectNode $id
            } else {
                wf::clearSelection
                set ::wf::propNameVar ""
                wf::setStatus "Nessun nodo selezionato"
            }
        }
    }
}

proc wf::dragStart {x y} {
    variable mode
    variable dragNode
    variable dragLastX
    variable dragLastY

    if {$mode ne "select"} return

    set id [wf::getNodeAt $x $y]
    if {$id ne ""} {
        set dragNode $id
        set dragLastX $x
        set dragLastY $y
        wf::selectNode $id
    }
}

proc wf::dragMove {x y} {
    variable dragNode
    variable dragLastX
    variable dragLastY
    variable canvas
    variable nodes

    if {$dragNode eq ""} return

    set dx [expr {$x - $dragLastX}]
    set dy [expr {$y - $dragLastY}]
    set dragLastX $x
    set dragLastY $y

    set rectId [dict get $nodes($dragNode) rect]
    set textId [dict get $nodes($dragNode) text]

    $canvas move $rectId $dx $dy
    $canvas move $textId $dx $dy

    dict incr nodes($dragNode) x $dx
    dict incr nodes($dragNode) y $dy

    wf::redrawEdgesForNode $dragNode
}

proc wf::dragEnd {} {
    variable dragNode
    set dragNode ""
}

# -----------------------------
# Save / load
# -----------------------------
proc wf::serialize {} {
    variable nodes
    variable edges

    set nodeList {}
    foreach id [array names nodes] {
        lappend nodeList [dict create \
            id   [dict get $nodes($id) id] \
            name [dict get $nodes($id) name] \
            x    [dict get $nodes($id) x] \
            y    [dict get $nodes($id) y]]
    }

    set edgeList {}
    foreach e $edges {
        lappend edgeList [dict create \
            from [dict get $e from] \
            to   [dict get $e to]]
    }

    return [dict create nodes $nodeList edges $edgeList]
}

proc wf::clearAll {} {
    variable canvas
    variable nodes
    variable edges
    variable selectedNode
    variable connectFrom
    variable propNameVar
    variable nextNodeId

    $canvas delete all
    catch {unset nodes}
    array set nodes {}
    set edges {}
    set selectedNode ""
    set connectFrom ""
    set propNameVar ""
    set nextNodeId 1
}

proc wf::loadSerialized {data} {
    variable nextNodeId

    wf::clearAll

    set maxId 0
    foreach n [dict get $data nodes] {
        set id   [dict get $n id]
        set name [dict get $n name]
        set x    [dict get $n x]
        set y    [dict get $n y]

        set created [wf::createNode $x $y $name]
        if {$created != $id} {
            # riallineamento id: ricrea struttura in modo coerente
            set ::wf::nodes($id) $::wf::nodes($created)
            dict set ::wf::nodes($id) id $id
            unset ::wf::nodes($created)

            set rectId [dict get $::wf::nodes($id) rect]
            set textId [dict get $::wf::nodes($id) text]
            $::wf::canvas dtag $rectId [wf::nodeTag $created]
            $::wf::canvas dtag $rectId [wf::nodeRectTag $created]
            $::wf::canvas addtag [wf::nodeTag $id] withtag $rectId
            $::wf::canvas addtag [wf::nodeRectTag $id] withtag $rectId

            $::wf::canvas dtag $textId [wf::nodeTag $created]
            $::wf::canvas dtag $textId [wf::nodeTextTag $created]
            $::wf::canvas addtag [wf::nodeTag $id] withtag $textId
            $::wf::canvas addtag [wf::nodeTextTag $id] withtag $textId
        }
        if {$id > $maxId} { set maxId $id }
    }
    set nextNodeId [expr {$maxId + 1}]

    foreach e [dict get $data edges] {
        wf::createEdge [dict get $e from] [dict get $e to]
    }

    wf::clearSelection
    wf::setStatus "Workflow caricato"
}

proc wf::saveToFile {} {
    set file [tk_getSaveFile \
        -title "Salva workflow" \
        -defaultextension ".wflow" \
        -filetypes {{"Workflow files" {.wflow}} {"All files" {*}}}]
    if {$file eq ""} return

    if {[catch {
        set f [open $file w]
        puts $f [wf::serialize]
        close $f
    } err]} {
        tk_messageBox -title "Errore" -message "Salvataggio fallito:\n$err" -icon error
        return
    }

    wf::setStatus "Workflow salvato in $file"
}

proc wf::loadFromFile {} {
    set file [tk_getOpenFile \
        -title "Apri workflow" \
        -filetypes {{"Workflow files" {.wflow}} {"All files" {*}}}]
    if {$file eq ""} return

    if {[catch {
        set f [open $file r]
        set data [read $f]
        close $f
        wf::loadSerialized $data
    } err]} {
        tk_messageBox -title "Errore" -message "Caricamento fallito:\n$err" -icon error
        return
    }
}

# -----------------------------
# Simulazione esecuzione
# -----------------------------
proc wf::incomingCount {nodeId} {
    variable edges
    set c 0
    foreach e $edges {
        if {[dict get $e to] == $nodeId} { incr c }
    }
    return $c
}

proc wf::outgoingNodes {nodeId} {
    variable edges
    set out {}
    foreach e $edges {
        if {[dict get $e from] == $nodeId} {
            lappend out [dict get $e to]
        }
    }
    return $out
}

proc wf::findStartNodes {} {
    variable nodes
    set starts {}
    foreach id [array names nodes] {
        if {[wf::incomingCount $id] == 0} {
            lappend starts $id
        }
    }
    return [lsort -integer $starts]
}

proc wf::flashNode {id color delay} {
    variable nodes
    variable canvas

    if {![info exists nodes($id)]} return
    set rectId [dict get $nodes($id) rect]

    after $delay [list $canvas itemconfigure $rectId -fill $color]
    after [expr {$delay + 500}] [list $canvas itemconfigure $rectId -fill "#e8f0ff"]
}

proc wf::runWorkflow {} {
    variable nodes

    if {[array size nodes] == 0} {
        wf::setStatus "Nessun workflow da eseguire"
        return
    }

    set queue [wf::findStartNodes]
    if {[llength $queue] == 0} {
        wf::setStatus "Nessun nodo iniziale trovato"
        return
    }

    set visited {}
    set delay 0

    while {[llength $queue] > 0} {
        set current [lindex $queue 0]
        set queue [lrange $queue 1 end]

        if {[lsearch -exact $visited $current] >= 0} {
            continue
        }
        lappend visited $current

        wf::flashNode $current "#c8f7c5" $delay
        incr delay 700

        foreach nxt [wf::outgoingNodes $current] {
            if {[lsearch -exact $visited $nxt] < 0} {
                lappend queue $nxt
            }
        }
    }

    wf::setStatus "Simulazione workflow avviata"
}

# -----------------------------
# UI
# -----------------------------
proc wf::setMode {m} {
    variable mode
    variable connectFrom
    set mode $m
    set connectFrom ""
    wf::updateModeUI
}

proc wf::updateModeUI {} {
    variable mode
    .toolbar.select state {!pressed}
    .toolbar.add state {!pressed}
    .toolbar.connect state {!pressed}

    switch -- $mode {
        select {
            .toolbar.select state {pressed}
            wf::setStatus "Modalità selezione"
        }
        add {
            .toolbar.add state {pressed}
            wf::setStatus "Modalità aggiunta: clicca nel canvas"
        }
        connect {
            .toolbar.connect state {pressed}
            wf::setStatus "Modalità collegamento: clicca nodo sorgente e poi destinazione"
        }
    }
}

proc wf::buildUI {} {
    variable canvas
    variable statusLabel

    wm title . "Workflow Editor - Tcl/Tk"
    wm geometry . 1100x700
    wm minsize . 900 600

    ttk::style theme use clam

    # Menu
    menu .menubar
    . configure -menu .menubar

    menu .menubar.file -tearoff 0
    .menubar add cascade -label "File" -menu .menubar.file
    .menubar.file add command -label "Nuovo" -command wf::clearAll
    .menubar.file add command -label "Apri..." -command wf::loadFromFile
    .menubar.file add command -label "Salva..." -command wf::saveToFile
    .menubar.file add separator
    .menubar.file add command -label "Esci" -command exit

    menu .menubar.run -tearoff 0
    .menubar add cascade -label "Esegui" -menu .menubar.run
    .menubar.run add command -label "Simula workflow" -command wf::runWorkflow

    # Toolbar
    ttk::frame .toolbar -padding 6
    pack .toolbar -fill x

    ttk::button .toolbar.select -text "Seleziona" -command {wf::setMode select}
    ttk::button .toolbar.add -text "Nuovo Nodo" -command {wf::setMode add}
    ttk::button .toolbar.connect -text "Collega" -command {wf::setMode connect}
    ttk::button .toolbar.run -text "Simula" -command wf::runWorkflow
    ttk::button .toolbar.delete -text "Elimina Nodo" -command wf::deleteSelectedNode

    pack .toolbar.select .toolbar.add .toolbar.connect .toolbar.run .toolbar.delete -side left -padx 3

    # Layout
    ttk::panedwindow .pw -orient horizontal
    pack .pw -fill both -expand 1

    ttk::frame .left -padding 6
    ttk::frame .right -padding 6
    .pw add .left -weight 4
    .pw add .right -weight 1

    # Canvas + scrollbar
    ttk::frame .left.wrap
    pack .left.wrap -fill both -expand 1

    set canvas [canvas .left.wrap.c -background white -scrollregion {0 0 2000 1200}]
    ttk::scrollbar .left.wrap.vsb -orient vertical -command "$canvas yview"
    ttk::scrollbar .left.wrap.hsb -orient horizontal -command "$canvas xview"
    $canvas configure -yscrollcommand ".left.wrap.vsb set" -xscrollcommand ".left.wrap.hsb set"

    grid $canvas -row 0 -column 0 -sticky nsew
    grid .left.wrap.vsb -row 0 -column 1 -sticky ns
    grid .left.wrap.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .left.wrap 0 -weight 1
    grid columnconfigure .left.wrap 0 -weight 1

    # Pannello proprietà
    ttk::labelframe .right.props -text "Proprietà nodo" -padding 10
    pack .right.props -fill x

    grid columnconfigure .right.props 1 -weight 1

    ttk::label .right.props.l1 -text "Nome:"
    ttk::entry .right.props.e1 -textvariable wf::propNameVar
    ttk::button .right.props.b1 -text "Applica" -command wf::renameSelectedNode

    grid .right.props.l1 -row 0 -column 0 -sticky w -pady 4
    grid .right.props.e1 -row 0 -column 1 -sticky ew -pady 4
    grid .right.props.b1 -row 1 -column 0 -columnspan 2 -sticky ew -pady 6

    ttk::labelframe .right.help -text "Uso" -padding 10
    pack .right.help -fill x -pady 12

    ttk::label .right.help.txt -justify left -text \
"1. Nuovo Nodo → clic nel canvas
2. Seleziona → trascina per muovere
3. Collega → clic sorgente, poi destinazione
4. Modifica nome nel pannello a destra
5. Simula per vedere il flusso"

    pack .right.help.txt -anchor w

    # Status bar
    ttk::separator .sep -orient horizontal
    pack .sep -fill x
    set statusLabel [ttk::label .status -text "Pronto" -padding 6]
    pack .status -fill x

    # Bind canvas
    bind $canvas <Button-1>       {wf::canvasClick [%W canvasx %x] [%W canvasy %y]}
    bind $canvas <ButtonPress-1>  {wf::dragStart  [%W canvasx %x] [%W canvasy %y]}
    bind $canvas <B1-Motion>      {wf::dragMove   [%W canvasx %x] [%W canvasy %y]}
    bind $canvas <ButtonRelease-1> {wf::dragEnd}

    # Demo iniziale
    set a [wf::createNode 180 120 "Start"]
    set b [wf::createNode 420 120 "Validazione"]
    set c [wf::createNode 680 120 "Elaborazione"]
    set d [wf::createNode 680 260 "Errore"]
    set e [wf::createNode 930 120 "Fine"]

    wf::createEdge $a $b
    wf::createEdge $b $c
    wf::createEdge $b $d
    wf::createEdge $c $e

    wf::clearSelection
    wf::setMode select
}

wf::buildUI