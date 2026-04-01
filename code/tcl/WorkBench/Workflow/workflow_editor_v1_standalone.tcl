#!/usr/bin/env wish

package require Tk 8.6

namespace eval wf {
    variable canvas
    variable statusLabel

    variable nodes
    array set nodes {}

    variable edges {}
    variable nextNodeId 1

    variable selectedNode ""
    variable mode "select"          ;# select | add | connect
    variable pendingNodeType "Process"
    variable connectFrom ""

    variable dragNode ""
    variable dragLastX 0
    variable dragLastY 0

    variable nodeWidth 130
    variable nodeHeight 56

    variable workflowFile ""

    # proprietà UI
    variable propName ""
    variable propType "Process"
    variable propLauncherProfile ""
    variable propConfigPath ""
    variable propNotes ""

    variable availableProfiles {
        "Radar Python Chain"
        "Satellite Matlab Visibility"
        "Underwater C++ Detector"
        "HDL Regression Runner"
    }

    variable nodeTypes {
        Start Scenario Config Process Decision Validation Log Output End
    }
}

# --------------------------------------------------
# Utility
# --------------------------------------------------
proc wf::setStatus {msg} {
    variable statusLabel
    if {[winfo exists $statusLabel]} {
        $statusLabel configure -text "Stato: $msg"
    }
}

proc wf::nodeTag {id} {
    return "node_$id"
}

proc wf::nodeRectTag {id} {
    return "node_rect_$id"
}

proc wf::nodeTextTag {id} {
    return "node_text_$id"
}

proc wf::edgeTag {from to} {
    return "edge_${from}_${to}"
}

proc wf::typeColor {type} {
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

proc wf::nodeLabel {id} {
    variable nodes
    set name [dict get $nodes($id) name]
    set type [dict get $nodes($id) type]
    return "$name\n<$type>"
}

proc wf::centerOfNode {id} {
    variable nodes
    return [list [dict get $nodes($id) x] [dict get $nodes($id) y]]
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

proc wf::edgeExists {from to} {
    variable edges
    foreach e $edges {
        if {[dict get $e from] == $from && [dict get $e to] == $to} {
            return 1
        }
    }
    return 0
}

# --------------------------------------------------
# Selection / properties
# --------------------------------------------------
proc wf::clearSelection {} {
    variable selectedNode
    variable nodes
    variable canvas

    if {$selectedNode ne "" && [info exists nodes($selectedNode)]} {
        set rectId [dict get $nodes($selectedNode) rect]
        $canvas itemconfigure $rectId -outline black -width 2
    }
    set selectedNode ""
}

proc wf::loadSelectedNodeProperties {} {
    variable selectedNode
    variable nodes
    variable propName
    variable propType
    variable propLauncherProfile
    variable propConfigPath
    variable propNotes

    if {$selectedNode eq "" || ![info exists nodes($selectedNode)]} {
        set propName ""
        set propType "Process"
        set propLauncherProfile ""
        set propConfigPath ""
        set propNotes ""
        return
    }

    set propName            [dict get $nodes($selectedNode) name]
    set propType            [dict get $nodes($selectedNode) type]
    set propLauncherProfile [dict get $nodes($selectedNode) launcherProfile]
    set propConfigPath      [dict get $nodes($selectedNode) configPath]
    set propNotes           [dict get $nodes($selectedNode) notes]
}

proc wf::selectNode {id} {
    variable selectedNode
    variable nodes
    variable canvas

    wf::clearSelection
    if {$id eq ""} { return }

    set selectedNode $id
    set rectId [dict get $nodes($id) rect]
    $canvas itemconfigure $rectId -outline blue -width 3
    wf::loadSelectedNodeProperties
    wf::setStatus "Nodo selezionato: [dict get $nodes($id) name]"
}

proc wf::applyNodeProperties {} {
    variable selectedNode
    variable nodes
    variable canvas
    variable propName
    variable propType
    variable propLauncherProfile
    variable propConfigPath
    variable propNotes

    if {$selectedNode eq "" || ![info exists nodes($selectedNode)]} {
        wf::setStatus "Nessun nodo selezionato"
        return
    }

    if {[string trim $propName] eq ""} {
        set propName "Node $selectedNode"
    }

    dict set nodes($selectedNode) name $propName
    dict set nodes($selectedNode) type $propType
    dict set nodes($selectedNode) launcherProfile $propLauncherProfile
    dict set nodes($selectedNode) configPath $propConfigPath
    dict set nodes($selectedNode) notes $propNotes

    set rectId [dict get $nodes($selectedNode) rect]
    set textId [dict get $nodes($selectedNode) text]

    $canvas itemconfigure $rectId -fill [wf::typeColor $propType]
    $canvas itemconfigure $textId -text [wf::nodeLabel $selectedNode]

    wf::setStatus "Proprietà aggiornate"
}

# --------------------------------------------------
# Node / edge management
# --------------------------------------------------
proc wf::createNode {x y {type "Process"} {name ""}} {
    variable canvas
    variable nodes
    variable nextNodeId
    variable nodeWidth
    variable nodeHeight

    set id $nextNodeId
    incr nextNodeId

    if {$name eq ""} {
        set name "$type $id"
    }

    set halfW [expr {$nodeWidth / 2}]
    set halfH [expr {$nodeHeight / 2}]
    set x1 [expr {$x - $halfW}]
    set y1 [expr {$y - $halfH}]
    set x2 [expr {$x + $halfW}]
    set y2 [expr {$y + $halfH}]

    set rect [$canvas create rectangle $x1 $y1 $x2 $y2 \
        -fill [wf::typeColor $type] -outline black -width 2 \
        -tags [list [wf::nodeTag $id] [wf::nodeRectTag $id]]]

    set text [$canvas create text $x $y \
        -text "$name\n<$type>" \
        -justify center \
        -font "TkDefaultFont 10" \
        -tags [list [wf::nodeTag $id] [wf::nodeTextTag $id]]]

    set nodes($id) [dict create \
        id $id \
        x $x \
        y $y \
        name $name \
        type $type \
        launcherProfile "" \
        configPath "" \
        notes "" \
        rect $rect \
        text $text]

    wf::selectNode $id
    return $id
}

proc wf::createEdge {from to} {
    variable edges
    variable canvas

    if {$from eq "" || $to eq "" || $from == $to} { return }
    if {[wf::edgeExists $from $to]} {
        wf::setStatus "Collegamento già presente"
        return
    }

    lassign [wf::centerOfNode $from] x1 y1
    lassign [wf::centerOfNode $to]   x2 y2

    set lineId [$canvas create line $x1 $y1 $x2 $y2 \
        -arrow last -width 2 -fill "#555555" \
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

proc wf::deleteSelectedNode {} {
    variable selectedNode
    variable nodes
    variable canvas
    variable edges

    if {$selectedNode eq "" || ![info exists nodes($selectedNode)]} {
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

    wf::clearSelection
    wf::loadSelectedNodeProperties
    wf::setStatus "Nodo eliminato"
}

# --------------------------------------------------
# Mouse interaction
# --------------------------------------------------
proc wf::canvasClick {x y} {
    variable mode
    variable connectFrom
    variable pendingNodeType

    set id [wf::getNodeAt $x $y]

    switch -- $mode {
        add {
            wf::createNode $x $y $pendingNodeType
            set ::wf::mode "select"
            wf::updateModeUI
        }
        connect {
            if {$id eq ""} {
                wf::setStatus "Clicca su due nodi per collegarli"
                return
            }
            if {$connectFrom eq ""} {
                set connectFrom $id
                wf::selectNode $id
                wf::setStatus "Nodo sorgente selezionato. Ora scegli la destinazione."
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
                wf::loadSelectedNodeProperties
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

    if {$mode ne "select"} { return }

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

    if {$dragNode eq ""} { return }

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

# --------------------------------------------------
# Serialization
# --------------------------------------------------
proc wf::serialize {} {
    variable nodes
    variable edges

    set nodeList {}
    foreach id [lsort -integer [array names nodes]] {
        lappend nodeList [dict create \
            id              [dict get $nodes($id) id] \
            x               [dict get $nodes($id) x] \
            y               [dict get $nodes($id) y] \
            name            [dict get $nodes($id) name] \
            type            [dict get $nodes($id) type] \
            launcherProfile [dict get $nodes($id) launcherProfile] \
            configPath      [dict get $nodes($id) configPath] \
            notes           [dict get $nodes($id) notes]]
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
    variable nextNodeId

    $canvas delete all

    catch {unset nodes}
    array set nodes {}
    set edges {}
    set selectedNode ""
    set connectFrom ""
    set nextNodeId 1

    wf::loadSelectedNodeProperties
    wf::setStatus "Workflow svuotato"
}

proc wf::loadSerialized {data} {
    variable nextNodeId
    variable nodes

    wf::clearAll
    set maxId 0

    foreach n [dict get $data nodes] {
        set id   [dict get $n id]
        set x    [dict get $n x]
        set y    [dict get $n y]
        set name [dict get $n name]
        set type [dict get $n type]

        set created [wf::createNode $x $y $type $name]

        dict set nodes($created) launcherProfile [dict get $n launcherProfile]
        dict set nodes($created) configPath      [dict get $n configPath]
        dict set nodes($created) notes           [dict get $n notes]

        if {$created != $id} {
            set nodes($id) $nodes($created)
            dict set nodes($id) id $id
            unset nodes($created)

            set rectId [dict get $nodes($id) rect]
            set textId [dict get $nodes($id) text]

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
    wf::loadSelectedNodeProperties
    wf::setStatus "Workflow caricato"
}

proc wf::saveWorkflow {} {
    variable workflowFile

    if {$workflowFile eq ""} {
        set workflowFile [tk_getSaveFile \
            -title "Salva workflow" \
            -defaultextension ".wflow" \
            -filetypes {{"Workflow files" {.wflow}} {"All files" {*}}}]
        if {$workflowFile eq ""} { return }
    }

    if {[catch {
        set f [open $workflowFile w]
        puts $f [wf::serialize]
        close $f
    } err]} {
        tk_messageBox -icon error -title "Errore" -message "Salvataggio fallito:\n$err"
        return
    }

    wm title . "Workflow Editor - [file tail $workflowFile]"
    wf::setStatus "Workflow salvato"
}

proc wf::saveWorkflowAs {} {
    variable workflowFile
    set workflowFile [tk_getSaveFile \
        -title "Salva workflow come" \
        -defaultextension ".wflow" \
        -filetypes {{"Workflow files" {.wflow}} {"All files" {*}}}]
    if {$workflowFile eq ""} { return }
    wf::saveWorkflow
}

proc wf::openWorkflow {} {
    variable workflowFile

    set f [tk_getOpenFile \
        -title "Apri workflow" \
        -filetypes {{"Workflow files" {.wflow}} {"All files" {*}}}]
    if {$f eq ""} { return }

    if {[catch {
        set ch [open $f r]
        set data [read $ch]
        close $ch
        wf::loadSerialized $data
        set workflowFile $f
    } err]} {
        tk_messageBox -icon error -title "Errore" -message "Caricamento fallito:\n$err"
        return
    }

    wm title . "Workflow Editor - [file tail $workflowFile]"
}

# --------------------------------------------------
# Simulation
# --------------------------------------------------
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
    if {![info exists nodes($id)]} { return }

    set rectId [dict get $nodes($id) rect]
    set oldColor [wf::typeColor [dict get $nodes($id) type]]

    after $delay [list $canvas itemconfigure $rectId -fill $color]
    after [expr {$delay + 450}] [list $canvas itemconfigure $rectId -fill $oldColor]
}

proc wf::simulateWorkflow {} {
    variable nodes

    if {[array size nodes] == 0} {
        wf::setStatus "Nessun workflow da simulare"
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

        wf::flashNode $current "#a4c2f4" $delay
        incr delay 650

        foreach nxt [wf::outgoingNodes $current] {
            if {[lsearch -exact $visited $nxt] < 0} {
                lappend queue $nxt
            }
        }
    }

    wf::setStatus "Simulazione avviata"
}

# --------------------------------------------------
# Preset workflow
# --------------------------------------------------
proc wf::loadRadarPreset {} {
    wf::clearAll

    set a [wf::createNode 130 120 Start "Start"]
    set b [wf::createNode 300 120 Scenario "Scenario"]
    set c [wf::createNode 480 120 Config "Radar Config"]
    set d [wf::createNode 670 120 Process "Preprocess"]
    set e [wf::createNode 860 120 Process "Detect"]
    set f [wf::createNode 860 250 Process "Track"]
    set g [wf::createNode 1040 120 Validation "Validate"]
    set h [wf::createNode 1220 120 Output "Export"]
    set i [wf::createNode 1040 250 Log "Analyze Log"]
    set j [wf::createNode 1220 250 End "End"]

    dict set ::wf::nodes($c) configPath "configs/radar_case_01.json"
    dict set ::wf::nodes($d) launcherProfile "Radar Python Chain"
    dict set ::wf::nodes($e) launcherProfile "Radar Python Chain"
    dict set ::wf::nodes($f) launcherProfile "Radar Python Chain"
    dict set ::wf::nodes($i) notes "Nodo pensato per Log Analyzer"

    foreach n [list $c $d $e $f $i] {
        set textId [dict get $::wf::nodes($n) text]
        $::wf::canvas itemconfigure $textId -text [wf::nodeLabel $n]
    }

    wf::createEdge $a $b
    wf::createEdge $b $c
    wf::createEdge $c $d
    wf::createEdge $d $e
    wf::createEdge $e $f
    wf::createEdge $e $g
    wf::createEdge $f $g
    wf::createEdge $g $h
    wf::createEdge $g $i
    wf::createEdge $i $j
    wf::createEdge $h $j

    wf::clearSelection
    wf::loadSelectedNodeProperties
    wf::setStatus "Preset radar caricato"
}

# --------------------------------------------------
# UI state
# --------------------------------------------------
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
            wf::setStatus "Modalità collegamento: scegli sorgente e destinazione"
        }
    }
}

proc wf::chooseConfigPath {} {
    variable propConfigPath
    set f [tk_getOpenFile -title "Seleziona config JSON" \
        -filetypes {{"JSON files" {.json}} {"All files" {*}}}]
    if {$f ne ""} {
        set propConfigPath $f
    }
}

# --------------------------------------------------
# UI
# --------------------------------------------------
proc wf::buildUI {} {
    variable canvas
    variable statusLabel

    wm title . "Workflow Editor"
    wm geometry . 1400x850
    wm minsize . 1100 700

    ttk::style theme use clam

    # menu
    menu .menubar
    . configure -menu .menubar

    menu .menubar.file -tearoff 0
    .menubar add cascade -label "File" -menu .menubar.file
    .menubar.file add command -label "Nuovo" -command wf::clearAll
    .menubar.file add command -label "Apri..." -command wf::openWorkflow
    .menubar.file add command -label "Salva" -command wf::saveWorkflow
    .menubar.file add command -label "Salva come..." -command wf::saveWorkflowAs
    .menubar.file add separator
    .menubar.file add command -label "Esci" -command exit

    menu .menubar.preset -tearoff 0
    .menubar add cascade -label "Preset" -menu .menubar.preset
    .menubar.preset add command -label "Radar pipeline" -command wf::loadRadarPreset

    # toolbar
    ttk::frame .toolbar -padding 6
    pack .toolbar -fill x

    ttk::button .toolbar.select  -text "Seleziona" -command {wf::setMode select}
    ttk::button .toolbar.add     -text "Nuovo nodo" -command {wf::setMode add}
    ttk::button .toolbar.connect -text "Collega" -command {wf::setMode connect}
    ttk::button .toolbar.delete  -text "Elimina nodo" -command wf::deleteSelectedNode
    ttk::button .toolbar.sim     -text "Simula" -command wf::simulateWorkflow
    ttk::button .toolbar.save    -text "Salva workflow" -command wf::saveWorkflow

    ttk::label .toolbar.typeL -text "Tipo nodo:"
    ttk::combobox .toolbar.typeC -state readonly \
        -values $::wf::nodeTypes \
        -textvariable wf::pendingNodeType

    pack .toolbar.select .toolbar.add .toolbar.connect .toolbar.delete .toolbar.sim .toolbar.save -side left -padx 3
    pack .toolbar.typeC -side right -padx 4
    pack .toolbar.typeL -side right -padx 4

    # main layout
    ttk::panedwindow .pw -orient horizontal
    pack .pw -fill both -expand 1

    ttk::frame .left -padding 6
    ttk::frame .right -padding 6
    .pw add .left -weight 4
    .pw add .right -weight 1

    # canvas area
    ttk::frame .left.wrap
    pack .left.wrap -fill both -expand 1

    set canvas [canvas .left.wrap.c -background white -scrollregion {0 0 2400 1600}]
    ttk::scrollbar .left.wrap.vsb -orient vertical -command "$canvas yview"
    ttk::scrollbar .left.wrap.hsb -orient horizontal -command "$canvas xview"
    $canvas configure -yscrollcommand ".left.wrap.vsb set" -xscrollcommand ".left.wrap.hsb set"

    grid $canvas -row 0 -column 0 -sticky nsew
    grid .left.wrap.vsb -row 0 -column 1 -sticky ns
    grid .left.wrap.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .left.wrap 0 -weight 1
    grid columnconfigure .left.wrap 0 -weight 1

    # right property panel
    ttk::labelframe .right.props -text "Proprietà nodo" -padding 10
    pack .right.props -fill x

    grid columnconfigure .right.props 1 -weight 1

    ttk::label .right.props.l1 -text "Nome:"
    ttk::entry .right.props.e1 -textvariable wf::propName

    ttk::label .right.props.l2 -text "Tipo:"
    ttk::combobox .right.props.c2 -state readonly \
        -values $::wf::nodeTypes \
        -textvariable wf::propType

    ttk::label .right.props.l3 -text "Launcher profile:"
    ttk::combobox .right.props.c3 -textvariable wf::propLauncherProfile \
        -values $::wf::availableProfiles

    ttk::label .right.props.l4 -text "Config path:"
    ttk::entry .right.props.e4 -textvariable wf::propConfigPath
    ttk::button .right.props.b4 -text "..." -width 3 -command wf::chooseConfigPath

    ttk::label .right.props.l5 -text "Note:"
    text .right.props.t5 -height 8 -width 28 -wrap word

    ttk::button .right.props.apply -text "Applica proprietà" -command {
        set ::wf::propNotes [string trim [.right.props.t5 get 1.0 end]]
        wf::applyNodeProperties
    }

    grid .right.props.l1 -row 0 -column 0 -sticky w -pady 4
    grid .right.props.e1 -row 0 -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.props.l2 -row 1 -column 0 -sticky w -pady 4
    grid .right.props.c2 -row 1 -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.props.l3 -row 2 -column 0 -sticky w -pady 4
    grid .right.props.c3 -row 2 -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.props.l4 -row 3 -column 0 -sticky w -pady 4
    grid .right.props.e4 -row 3 -column 1 -sticky ew -pady 4
    grid .right.props.b4 -row 3 -column 2 -sticky ew -padx 4

    grid .right.props.l5 -row 4 -column 0 -sticky nw -pady 4
    grid .right.props.t5 -row 4 -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.props.apply -row 5 -column 0 -columnspan 3 -sticky ew -pady 8

    ttk::labelframe .right.help -text "Uso" -padding 10
    pack .right.help -fill x -pady 12

    ttk::label .right.help.txt -justify left -text \
"1. Scegli il tipo nodo
2. Premi 'Nuovo nodo'
3. Clic nel canvas
4. Seleziona un nodo per editarlo
5. 'Collega' per creare archi
6. 'Simula' per vedere il flusso

Pensato per il workbench:
- Config node → config JSON
- Process node → launcher profile
- Log node → analisi log
- Output node → artifact/output"

    pack .right.help.txt -anchor w

    # status
    ttk::separator .sep -orient horizontal
    pack .sep -fill x
    set statusLabel [ttk::label .status -text "Stato: pronto" -padding 6]
    pack .status -fill x

    # bindings
    bind $canvas <Button-1>        {wf::canvasClick [%W canvasx %x] [%W canvasy %y]}
    bind $canvas <ButtonPress-1>   {wf::dragStart  [%W canvasx %x] [%W canvasy %y]}
    bind $canvas <B1-Motion>       {wf::dragMove   [%W canvasx %x] [%W canvasy %y]}
    bind $canvas <ButtonRelease-1> {wf::dragEnd}

    bind .right.props.e1 <KeyRelease> {
        # non scriviamo subito sul modello; aggiorniamo solo il text widget note quando cambia selezione
    }

    wf::setMode select
}

proc wf::syncNotesWidget {} {
    .right.props.t5 delete 1.0 end
    .right.props.t5 insert end $::wf::propNotes
}

# Hook selezione -> aggiornamento note widget
rename wf::loadSelectedNodeProperties wf::loadSelectedNodeProperties_impl
proc wf::loadSelectedNodeProperties {} {
    wf::loadSelectedNodeProperties_impl
    if {[winfo exists .right.props.t5]} {
        wf::syncNotesWidget
    }
}

# --------------------------------------------------
# Main
# --------------------------------------------------
wf::buildUI
wf::loadRadarPreset