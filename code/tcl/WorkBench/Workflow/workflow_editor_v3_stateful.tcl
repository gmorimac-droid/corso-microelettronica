#!/usr/bin/env wish

package require Tk 8.6

namespace eval wf {
    variable canvas
    variable statusLabel
    variable logText

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

    variable nodeWidth 140
    variable nodeHeight 60

    variable workflowFile ""

    variable processChan ""
    variable processPid ""
    variable runningNode ""
    variable running 0

    variable propName ""
    variable propType "Process"
    variable propLauncherProfile ""
    variable propConfigPath ""
    variable propLogPath ""
    variable propWorkDir "."
    variable propExtraArgs ""
    variable propNotes ""

    variable propState ""
    variable propLastMessage ""
    variable propLastExitCode ""
    variable propLastRunTs ""

    variable executionQueue {}
    variable currentRunOutputDir ""

    variable launcherProfiles
    array set launcherProfiles {
        "Radar Python Chain"          {type python_script launcher python3 target radar_chain.py workdir . extra_args {--mode batch}}
        "Satellite Matlab Visibility" {type matlab_function launcher matlab target run_visibility_case workdir . extra_args {}}
        "Underwater C++ Detector"     {type cpp_executable launcher {} target ./uw_detector workdir . extra_args {--threshold auto}}
        "HDL Regression Runner"       {type hdl_runner launcher python3 target run_hdl_regression.py workdir . extra_args {--suite smoke --waves}}
    }

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

proc wf::log {msg {tag info}} {
    variable logText
    set ts [clock format [clock seconds] -format "%H:%M:%S"]
    if {[winfo exists $logText]} {
        $logText insert end "[$ts] $msg\n" $tag
        $logText see end
    }
}

proc wf::configureLogTags {} {
    variable logText
    $logText tag configure info  -foreground black
    $logText tag configure ok    -foreground darkgreen
    $logText tag configure warn  -foreground darkorange3
    $logText tag configure error -foreground red
    $logText tag configure run   -foreground blue
}

proc wf::openPath {path} {
    if {$path eq ""} { return }
    if {![file exists $path]} {
        wf::log "Percorso non trovato: $path" warn
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

proc wf::nodeTag {id} { return "node_$id" }
proc wf::nodeRectTag {id} { return "node_rect_$id" }
proc wf::nodeTextTag {id} { return "node_text_$id" }
proc wf::edgeTag {from to} { return "edge_${from}_${to}" }

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
# Runtime state
# --------------------------------------------------
proc wf::refreshNodeVisualState {nodeId} {
    variable nodes
    variable canvas
    variable selectedNode

    if {![info exists nodes($nodeId)]} { return }

    set rectId [dict get $nodes($nodeId) rect]
    set state  [dict get $nodes($nodeId) state]

    switch -- $state {
        idle {
            if {$selectedNode eq $nodeId} {
                $canvas itemconfigure $rectId -outline blue -width 3
            } else {
                $canvas itemconfigure $rectId -outline black -width 2
            }
        }
        running {
            $canvas itemconfigure $rectId -outline blue -width 4
        }
        ok {
            $canvas itemconfigure $rectId -outline darkgreen -width 4
        }
        failed {
            $canvas itemconfigure $rectId -outline red -width 4
        }
        skipped {
            $canvas itemconfigure $rectId -outline gray50 -width 3
        }
        default {
            $canvas itemconfigure $rectId -outline black -width 2
        }
    }
}

proc wf::setNodeState {nodeId state {msg ""} {exitCode ""}} {
    variable nodes
    variable selectedNode

    if {![info exists nodes($nodeId)]} { return }

    dict set nodes($nodeId) state $state
    dict set nodes($nodeId) lastMessage $msg
    dict set nodes($nodeId) lastExitCode $exitCode
    dict set nodes($nodeId) lastRunTs [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

    wf::refreshNodeVisualState $nodeId

    if {$selectedNode eq $nodeId} {
        wf::loadSelectedNodeProperties
    }
}

proc wf::resetAllNodeStates {} {
    variable nodes
    variable selectedNode

    foreach id [array names nodes] {
        dict set nodes($id) state "idle"
        dict set nodes($id) lastMessage ""
        dict set nodes($id) lastExitCode ""
        dict set nodes($id) lastRunTs ""
        wf::refreshNodeVisualState $id
    }

    if {$selectedNode ne ""} {
        wf::loadSelectedNodeProperties
    }

    wf::log "Stati workflow resettati" info
    wf::setStatus "Stati workflow resettati"
}

# --------------------------------------------------
# Selection / properties
# --------------------------------------------------
proc wf::clearSelection {} {
    variable selectedNode
    variable nodes

    if {$selectedNode ne "" && [info exists nodes($selectedNode)]} {
        wf::refreshNodeVisualState $selectedNode
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
    variable propLogPath
    variable propWorkDir
    variable propExtraArgs
    variable propNotes
    variable propState
    variable propLastMessage
    variable propLastExitCode
    variable propLastRunTs

    if {$selectedNode eq "" || ![info exists nodes($selectedNode)]} {
        set propName ""
        set propType "Process"
        set propLauncherProfile ""
        set propConfigPath ""
        set propLogPath ""
        set propWorkDir "."
        set propExtraArgs ""
        set propNotes ""
        set propState ""
        set propLastMessage ""
        set propLastExitCode ""
        set propLastRunTs ""

        if {[winfo exists .right.props.t6]} {
            .right.props.t6 delete 1.0 end
        }
        return
    }

    set propName            [dict get $nodes($selectedNode) name]
    set propType            [dict get $nodes($selectedNode) type]
    set propLauncherProfile [dict get $nodes($selectedNode) launcherProfile]
    set propConfigPath      [dict get $nodes($selectedNode) configPath]
    set propLogPath         [dict get $nodes($selectedNode) logPath]
    set propWorkDir         [dict get $nodes($selectedNode) workDir]
    set propExtraArgs       [dict get $nodes($selectedNode) extraArgs]
    set propNotes           [dict get $nodes($selectedNode) notes]
    set propState           [dict get $nodes($selectedNode) state]
    set propLastMessage     [dict get $nodes($selectedNode) lastMessage]
    set propLastExitCode    [dict get $nodes($selectedNode) lastExitCode]
    set propLastRunTs       [dict get $nodes($selectedNode) lastRunTs]

    if {[winfo exists .right.props.t6]} {
        .right.props.t6 delete 1.0 end
        .right.props.t6 insert end $propNotes
    }
}

proc wf::selectNode {id} {
    variable selectedNode
    variable nodes

    wf::clearSelection
    if {$id eq ""} { return }

    set selectedNode $id
    wf::refreshNodeVisualState $id
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
    variable propLogPath
    variable propWorkDir
    variable propExtraArgs
    variable propNotes

    if {$selectedNode eq "" || ![info exists nodes($selectedNode)]} {
        wf::setStatus "Nessun nodo selezionato"
        return
    }

    if {[string trim $propName] eq ""} {
        set propName "Node $selectedNode"
    }

    dict set nodes($selectedNode) name            $propName
    dict set nodes($selectedNode) type            $propType
    dict set nodes($selectedNode) launcherProfile $propLauncherProfile
    dict set nodes($selectedNode) configPath      $propConfigPath
    dict set nodes($selectedNode) logPath         $propLogPath
    dict set nodes($selectedNode) workDir         $propWorkDir
    dict set nodes($selectedNode) extraArgs       $propExtraArgs
    dict set nodes($selectedNode) notes           $propNotes

    set rectId [dict get $nodes($selectedNode) rect]
    set textId [dict get $nodes($selectedNode) text]

    $canvas itemconfigure $rectId -fill [wf::typeColor $propType]
    $canvas itemconfigure $textId -text [wf::nodeLabel $selectedNode]
    wf::refreshNodeVisualState $selectedNode

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
        logPath "" \
        workDir "." \
        extraArgs "" \
        notes "" \
        lastOutputDir "" \
        state "idle" \
        lastMessage "" \
        lastExitCode "" \
        lastRunTs "" \
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
            logPath         [dict get $nodes($id) logPath] \
            workDir         [dict get $nodes($id) workDir] \
            extraArgs       [dict get $nodes($id) extraArgs] \
            notes           [dict get $nodes($id) notes] \
            state           [dict get $nodes($id) state] \
            lastMessage     [dict get $nodes($id) lastMessage] \
            lastExitCode    [dict get $nodes($id) lastExitCode] \
            lastRunTs       [dict get $nodes($id) lastRunTs] \
            lastOutputDir   [dict get $nodes($id) lastOutputDir]]
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

        foreach key {launcherProfile configPath logPath workDir extraArgs notes state lastMessage lastExitCode lastRunTs lastOutputDir} {
            if {[dict exists $n $key]} {
                dict set nodes($created) $key [dict get $n $key]
            }
        }

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

    foreach id [array names nodes] {
        wf::refreshNodeVisualState $id
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

    wm title . "Workflow Editor V3 - [file tail $workflowFile]"
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

    wm title . "Workflow Editor V3 - [file tail $workflowFile]"
}

# --------------------------------------------------
# Workflow traversal / simulation
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

proc wf::topologicalWalk {} {
    variable nodes
    if {[array size nodes] == 0} { return {} }

    set queue [wf::findStartNodes]
    set visited {}
    set ordered {}

    while {[llength $queue] > 0} {
        set current [lindex $queue 0]
        set queue [lrange $queue 1 end]

        if {[lsearch -exact $visited $current] >= 0} { continue }
        lappend visited $current
        lappend ordered $current

        foreach nxt [wf::outgoingNodes $current] {
            if {[lsearch -exact $visited $nxt] < 0} {
                lappend queue $nxt
            }
        }
    }

    return $ordered
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
    set ordered [wf::topologicalWalk]
    if {[llength $ordered] == 0} {
        wf::setStatus "Nessun workflow da simulare"
        return
    }

    set delay 0
    foreach nodeId $ordered {
        wf::flashNode $nodeId "#a4c2f4" $delay
        incr delay 600
    }
    wf::setStatus "Simulazione avviata"
}

# --------------------------------------------------
# Operational layer
# --------------------------------------------------
proc wf::buildRunOutputDir {nodeId} {
    variable nodes
    set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
    set safe [string map {" " "_" "/" "_" "\\" "_"} [dict get $nodes($nodeId) name]]
    return [file join runs $safe $ts]
}

proc wf::splitArgs {argString} {
    if {[string trim $argString] eq ""} { return {} }
    return $argString
}

proc wf::buildCommandForNode {nodeId} {
    variable nodes
    variable launcherProfiles

    if {![info exists nodes($nodeId)]} {
        return [list {} "" ""]
    }

    set type [dict get $nodes($nodeId) type]
    set configPath [dict get $nodes($nodeId) configPath]
    set profile [dict get $nodes($nodeId) launcherProfile]
    set workDir [dict get $nodes($nodeId) workDir]
    set extraArgs [dict get $nodes($nodeId) extraArgs]
    set outputDir [wf::buildRunOutputDir $nodeId]

    if {$type ne "Process"} {
        return [list {} $outputDir $workDir]
    }

    if {$profile eq ""} {
        return [list {} $outputDir $workDir]
    }

    if {![info exists launcherProfiles($profile)]} {
        return [list {} $outputDir $workDir]
    }

    array set p $launcherProfiles($profile)
    set cmd {}

    switch -- $p(type) {
        python_script {
            lappend cmd $p(launcher) $p(target)
            if {$configPath ne ""} { lappend cmd --config $configPath }
            lappend cmd --output $outputDir
            foreach a [wf::splitArgs $p(extra_args)] { lappend cmd $a }
            foreach a [wf::splitArgs $extraArgs] { lappend cmd $a }
        }
        cpp_executable {
            lappend cmd $p(target)
            if {$configPath ne ""} { lappend cmd --config $configPath }
            lappend cmd --output $outputDir
            foreach a [wf::splitArgs $p(extra_args)] { lappend cmd $a }
            foreach a [wf::splitArgs $extraArgs] { lappend cmd $a }
        }
        hdl_runner {
            lappend cmd $p(launcher) $p(target)
            if {$configPath ne ""} { lappend cmd --config $configPath }
            lappend cmd --output $outputDir
            foreach a [wf::splitArgs $p(extra_args)] { lappend cmd $a }
            foreach a [wf::splitArgs $extraArgs] { lappend cmd $a }
        }
        matlab_function {
            if {$configPath eq ""} {
                set expr "$p(target)()"
            } else {
                set expr [format "%s('%s')" $p(target) $configPath]
            }
            lappend cmd $p(launcher) -batch $expr
        }
        default {
            return [list {} $outputDir $workDir]
        }
    }

    if {$workDir eq ""} {
        set workDir $p(workdir)
    }

    return [list $cmd $outputDir $workDir]
}

proc wf::executeSelectedNode {} {
    variable selectedNode
    if {$selectedNode eq ""} {
        wf::setStatus "Seleziona un nodo"
        return
    }
    wf::executeNode $selectedNode
}

proc wf::executeNode {nodeId} {
    variable nodes
    variable running
    variable processChan
    variable processPid
    variable runningNode

    if {$running} {
        wf::log "C'è già un processo in esecuzione" warn
        return
    }

    if {![info exists nodes($nodeId)]} { return }

    set type [dict get $nodes($nodeId) type]
    set name [dict get $nodes($nodeId) name]

    switch -- $type {
        Config {
            set path [dict get $nodes($nodeId) configPath]
            if {$path eq "" || ![file exists $path]} {
                wf::setNodeState $nodeId failed "Config non trovata" 1
                wf::log "Nodo Config '$name' fallito: file non trovato" error
                return
            }
            wf::openPath $path
            wf::setNodeState $nodeId ok "Config aperta" 0
            wf::log "Aperta config del nodo '$name': $path" ok
            return
        }
        Log {
            set path [dict get $nodes($nodeId) logPath]
            if {$path eq "" || ![file exists $path]} {
                wf::setNodeState $nodeId failed "Log non trovato" 1
                wf::log "Nodo Log '$name' fallito: file non trovato" error
                return
            }
            wf::openPath $path
            wf::setNodeState $nodeId ok "Log aperto" 0
            wf::log "Aperto log del nodo '$name': $path" ok
            return
        }
        Output {
            set path [dict get $nodes($nodeId) lastOutputDir]
            if {$path eq "" || ![file exists $path]} {
                wf::setNodeState $nodeId failed "Output non disponibile" 1
                wf::log "Nodo Output '$name' fallito: cartella output non trovata" error
                return
            }
            wf::openPath $path
            wf::setNodeState $nodeId ok "Output aperto" 0
            wf::log "Aperta cartella output del nodo '$name': $path" ok
            return
        }
        Process {
            lassign [wf::buildCommandForNode $nodeId] cmd outdir workdir
            if {[llength $cmd] == 0} {
                wf::setNodeState $nodeId failed "Nodo Process non configurato" 1
                wf::log "Nodo Process non configurato correttamente: $name" warn
                return
            }

            file mkdir $outdir
            dict set nodes($nodeId) lastOutputDir $outdir

            set oldDir [pwd]
            if {$workdir ne "" && [file isdirectory $workdir]} {
                cd $workdir
            }

            wf::setNodeState $nodeId running "Nodo in esecuzione" ""

            if {[catch {
                set processChan [open "|[list {*}$cmd] 2>@1" r]
                fconfigure $processChan -blocking 0 -buffering line
                fileevent $processChan readable [list wf::onProcessReadable $processChan]
                set processPid [pid $processChan]
                set running 1
                set runningNode $nodeId
            } err]} {
                cd $oldDir
                wf::setNodeState $nodeId failed "Avvio fallito: $err" 1
                wf::log "Avvio fallito per '$name': $err" error
                return
            }

            cd $oldDir
            wf::log "Nodo '$name' avviato" run
            wf::log "CMD: [join $cmd { }]" info
            wf::log "Output dir: $outdir" info
            wf::setStatus "Nodo in esecuzione: $name"
            return
        }
        default {
            wf::setNodeState $nodeId ok "Azione locale completata" 0
            wf::log "Nodo '$name' di tipo $type: nessuna azione operativa associata" info
            return
        }
    }
}

proc wf::onProcessReadable {chan} {
    variable running
    variable processChan
    variable processPid
    variable runningNode
    variable nodes
    variable executionQueue

    if {[eof $chan]} {
        set closeMsg ""
        if {[catch {close $chan} err]} {
            set closeMsg $err
        }

        if {$runningNode ne "" && [info exists nodes($runningNode)]} {
            set name [dict get $nodes($runningNode) name]
            if {$closeMsg ne ""} {
                wf::setNodeState $runningNode failed $closeMsg 1
                wf::log "Nodo '$name' terminato: $closeMsg" warn
                set executionQueue {}
                wf::setStatus "Workflow fermato su errore"
            } else {
                wf::setNodeState $runningNode ok "Terminato correttamente" 0
                wf::log "Nodo '$name' terminato correttamente" ok
            }
        }

        set running 0
        set processChan ""
        set processPid ""
        set runningNode ""

        if {[llength $executionQueue] > 0} {
            after 200 wf::executeNextInQueue
        } else {
            if {$closeMsg eq ""} {
                wf::setStatus "Esecuzione completata"
            }
        }
        return
    }

    if {[gets $chan line] >= 0} {
        set u [string toupper $line]
        if {[string match "*ERROR*" $u] || [string match "*FATAL*" $u]} {
            wf::log $line error
        } elseif {[string match "*WARN*" $u] || [string match "*WARNING*" $u]} {
            wf::log $line warn
        } else {
            wf::log $line info
        }
    }
}

proc wf::executeNextInQueue {} {
    variable executionQueue
    if {[llength $executionQueue] == 0} {
        wf::setStatus "Coda esecuzione finita"
        return
    }
    set nodeId [lindex $executionQueue 0]
    set executionQueue [lrange $executionQueue 1 end]
    wf::executeNode $nodeId
}

proc wf::runWorkflowSequence {} {
    variable executionQueue
    variable running
    variable nodes

    if {$running} {
        wf::log "C'è già un processo in esecuzione" warn
        return
    }

    set ordered [wf::topologicalWalk]
    if {[llength $ordered] == 0} {
        wf::setStatus "Workflow vuoto"
        return
    }

    wf::resetAllNodeStates

    set queue {}
    foreach nodeId $ordered {
        if {[dict get $nodes($nodeId) type] eq "Process"} {
            lappend queue $nodeId
        }
    }

    if {[llength $queue] == 0} {
        wf::log "Nessun nodo Process nel workflow" warn
        return
    }

    set executionQueue $queue
    wf::log "Avvio esecuzione sequenziale di [llength $queue] nodi Process" run
    wf::executeNextInQueue
}

proc wf::stopExecution {} {
    variable running
    variable processChan
    variable processPid
    variable runningNode
    variable executionQueue

    set executionQueue {}

    if {!$running} {
        wf::setStatus "Nessun processo attivo"
        return
    }

    if {$processPid ne ""} {
        catch {exec kill $processPid}
    }
    catch {close $processChan}

    if {$runningNode ne ""} {
        wf::setNodeState $runningNode failed "Interrotto manualmente" 1
    }

    set running 0
    set processChan ""
    set processPid ""
    set runningNode ""

    wf::log "Esecuzione interrotta" warn
    wf::setStatus "Esecuzione fermata"
}

# --------------------------------------------------
# Operational helpers
# --------------------------------------------------
proc wf::openSelectedConfig {} {
    variable selectedNode
    variable nodes
    if {$selectedNode eq ""} { return }
    set path [dict get $nodes($selectedNode) configPath]
    if {$path eq ""} {
        wf::log "Nessun configPath sul nodo selezionato" warn
        return
    }
    wf::openPath $path
}

proc wf::openSelectedLog {} {
    variable selectedNode
    variable nodes
    if {$selectedNode eq ""} { return }
    set path [dict get $nodes($selectedNode) logPath]
    if {$path eq ""} {
        wf::log "Nessun logPath sul nodo selezionato" warn
        return
    }
    wf::openPath $path
}

proc wf::openSelectedOutput {} {
    variable selectedNode
    variable nodes
    if {$selectedNode eq ""} { return }
    set path [dict get $nodes($selectedNode) lastOutputDir]
    if {$path eq ""} {
        wf::log "Nessun output disponibile sul nodo selezionato" warn
        return
    }
    wf::openPath $path
}

# --------------------------------------------------
# Preset workflow
# --------------------------------------------------
proc wf::loadRadarPreset {} {
    wf::clearAll

    set a [wf::createNode 120 120 Start "Start"]
    set b [wf::createNode 290 120 Scenario "Scenario"]
    set c [wf::createNode 470 120 Config "Radar Config"]
    set d [wf::createNode 660 120 Process "Preprocess"]
    set e [wf::createNode 850 120 Process "Detect"]
    set f [wf::createNode 850 260 Process "Track"]
    set g [wf::createNode 1040 120 Validation "Validate"]
    set h [wf::createNode 1220 120 Output "Export"]
    set i [wf::createNode 1040 260 Log "Run Log"]
    set j [wf::createNode 1220 260 End "End"]

    dict set ::wf::nodes($c) configPath "configs/radar_case_01.json"
    dict set ::wf::nodes($d) launcherProfile "Radar Python Chain"
    dict set ::wf::nodes($d) configPath "configs/radar_case_01.json"
    dict set ::wf::nodes($e) launcherProfile "Radar Python Chain"
    dict set ::wf::nodes($e) configPath "configs/radar_case_01.json"
    dict set ::wf::nodes($f) launcherProfile "Radar Python Chain"
    dict set ::wf::nodes($f) configPath "configs/radar_case_01.json"
    dict set ::wf::nodes($i) logPath "runs/example/run.log"
    dict set ::wf::nodes($h) notes "Apri output dell'ultimo nodo Process eseguito"

    foreach n [list $c $d $e $f $i $h] {
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
    wf::createEdge $h $j
    wf::createEdge $i $j

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
    if {$f ne ""} { set propConfigPath $f }
}

proc wf::chooseLogPath {} {
    variable propLogPath
    set f [tk_getOpenFile -title "Seleziona file log" \
        -filetypes {{"Log files" {.log .txt .out}} {"All files" {*}}}]
    if {$f ne ""} { set propLogPath $f }
}

proc wf::chooseWorkDir {} {
    variable propWorkDir
    set d [tk_chooseDirectory -title "Seleziona working directory"]
    if {$d ne ""} { set propWorkDir $d }
}

# --------------------------------------------------
# UI
# --------------------------------------------------
proc wf::buildUI {} {
    variable canvas
    variable statusLabel
    variable logText

    wm title . "Workflow Editor V3"
    wm geometry . 1520x940
    wm minsize . 1200 780

    ttk::style theme use clam

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

    ttk::frame .toolbar -padding 6
    pack .toolbar -fill x

    ttk::button .toolbar.select      -text "Seleziona" -command {wf::setMode select}
    ttk::button .toolbar.add         -text "Nuovo nodo" -command {wf::setMode add}
    ttk::button .toolbar.connect     -text "Collega" -command {wf::setMode connect}
    ttk::button .toolbar.delete      -text "Elimina nodo" -command wf::deleteSelectedNode
    ttk::button .toolbar.sim         -text "Simula" -command wf::simulateWorkflow
    ttk::button .toolbar.runone      -text "Esegui nodo" -command wf::executeSelectedNode
    ttk::button .toolbar.runall      -text "Esegui workflow" -command wf::runWorkflowSequence
    ttk::button .toolbar.resetstates -text "Reset stati" -command wf::resetAllNodeStates
    ttk::button .toolbar.stop        -text "Stop" -command wf::stopExecution
    ttk::button .toolbar.save        -text "Salva workflow" -command wf::saveWorkflow

    ttk::label .toolbar.typeL -text "Tipo nodo:"
    ttk::combobox .toolbar.typeC -state readonly \
        -values $::wf::nodeTypes \
        -textvariable wf::pendingNodeType

    pack .toolbar.select .toolbar.add .toolbar.connect .toolbar.delete \
         .toolbar.sim .toolbar.runone .toolbar.runall .toolbar.resetstates \
         .toolbar.stop .toolbar.save \
         -side left -padx 3
    pack .toolbar.typeC -side right -padx 4
    pack .toolbar.typeL -side right -padx 4

    ttk::panedwindow .pw -orient horizontal
    pack .pw -fill both -expand 1

    ttk::frame .left -padding 6
    ttk::frame .right -padding 6
    .pw add .left -weight 4
    .pw add .right -weight 1

    ttk::frame .left.wrap
    pack .left.wrap -fill both -expand 1

    set canvas [canvas .left.wrap.c -background white -scrollregion {0 0 2600 1800}]
    ttk::scrollbar .left.wrap.vsb -orient vertical -command "$canvas yview"
    ttk::scrollbar .left.wrap.hsb -orient horizontal -command "$canvas xview"
    $canvas configure -yscrollcommand ".left.wrap.vsb set" -xscrollcommand ".left.wrap.hsb set"

    grid $canvas -row 0 -column 0 -sticky nsew
    grid .left.wrap.vsb -row 0 -column 1 -sticky ns
    grid .left.wrap.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .left.wrap 0 -weight 1
    grid columnconfigure .left.wrap 0 -weight 1

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

    ttk::label .right.props.l5 -text "Log path:"
    ttk::entry .right.props.e5 -textvariable wf::propLogPath
    ttk::button .right.props.b5 -text "..." -width 3 -command wf::chooseLogPath

    ttk::label .right.props.l6 -text "Work dir:"
    ttk::entry .right.props.e6 -textvariable wf::propWorkDir
    ttk::button .right.props.b6 -text "..." -width 3 -command wf::chooseWorkDir

    ttk::label .right.props.l7 -text "Extra args:"
    ttk::entry .right.props.e7 -textvariable wf::propExtraArgs

    ttk::label .right.props.l8 -text "Note:"
    text .right.props.t6 -height 6 -width 28 -wrap word

    ttk::button .right.props.apply -text "Applica proprietà" -command {
        set ::wf::propNotes [string trim [.right.props.t6 get 1.0 end]]
        wf::applyNodeProperties
    }

    ttk::frame .right.actions
    pack .right.actions -fill x -pady 10
    ttk::button .right.actions.oc -text "Apri config" -command wf::openSelectedConfig
    ttk::button .right.actions.ol -text "Apri log" -command wf::openSelectedLog
    ttk::button .right.actions.oo -text "Apri output" -command wf::openSelectedOutput
    pack .right.actions.oc .right.actions.ol .right.actions.oo -fill x -pady 2

    grid .right.props.l1 -row 0 -column 0 -sticky w -pady 4
    grid .right.props.e1 -row 0 -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.props.l2 -row 1 -column 0 -sticky w -pady 4
    grid .right.props.c2 -row 1 -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.props.l3 -row 2 -column 0 -sticky w -pady 4
    grid .right.props.c3 -row 2 -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.props.l4 -row 3 -column 0 -sticky w -pady 4
    grid .right.props.e4 -row 3 -column 1 -sticky ew -pady 4
    grid .right.props.b4 -row 3 -column 2 -sticky ew -padx 4

    grid .right.props.l5 -row 4 -column 0 -sticky w -pady 4
    grid .right.props.e5 -row 4 -column 1 -sticky ew -pady 4
    grid .right.props.b5 -row 4 -column 2 -sticky ew -padx 4

    grid .right.props.l6 -row 5 -column 0 -sticky w -pady 4
    grid .right.props.e6 -row 5 -column 1 -sticky ew -pady 4
    grid .right.props.b6 -row 5 -column 2 -sticky ew -padx 4

    grid .right.props.l7 -row 6 -column 0 -sticky w -pady 4
    grid .right.props.e7 -row 6 -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.props.l8 -row 7 -column 0 -sticky nw -pady 4
    grid .right.props.t6 -row 7 -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.props.apply -row 8 -column 0 -columnspan 3 -sticky ew -pady 8

    ttk::labelframe .right.runtime -text "Stato runtime" -padding 10
    pack .right.runtime -fill x -pady 8
    grid columnconfigure .right.runtime 1 -weight 1

    ttk::label .right.runtime.l1 -text "State:"
    ttk::entry .right.runtime.e1 -textvariable wf::propState -state readonly

    ttk::label .right.runtime.l2 -text "Last message:"
    ttk::entry .right.runtime.e2 -textvariable wf::propLastMessage -state readonly

    ttk::label .right.runtime.l3 -text "Exit code:"
    ttk::entry .right.runtime.e3 -textvariable wf::propLastExitCode -state readonly

    ttk::label .right.runtime.l4 -text "Last run:"
    ttk::entry .right.runtime.e4 -textvariable wf::propLastRunTs -state readonly

    grid .right.runtime.l1 -row 0 -column 0 -sticky w -pady 3
    grid .right.runtime.e1 -row 0 -column 1 -sticky ew -pady 3
    grid .right.runtime.l2 -row 1 -column 0 -sticky w -pady 3
    grid .right.runtime.e2 -row 1 -column 1 -sticky ew -pady 3
    grid .right.runtime.l3 -row 2 -column 0 -sticky w -pady 3
    grid .right.runtime.e3 -row 2 -column 1 -sticky ew -pady 3
    grid .right.runtime.l4 -row 3 -column 0 -sticky w -pady 3
    grid .right.runtime.e4 -row 3 -column 1 -sticky ew -pady 3

    ttk::labelframe .right.help -text "Uso operativo" -padding 10
    pack .right.help -fill x -pady 10

    ttk::label .right.help.txt -justify left -text \
"Config:
- apre il file JSON associato

Process:
- usa launcher profile + configPath
- crea output in runs/<nodo>/<timestamp>

Log:
- apre il file log associato

Output:
- apre l'ultimo output generato dal nodo

Stati:
- idle
- running
- ok
- failed

'Esegui workflow':
- esegue in sequenza tutti i nodi Process
- si ferma al primo errore"

    pack .right.help.txt -anchor w

    ttk::labelframe .right.logbox -text "Execution log" -padding 8
    pack .right.logbox -fill both -expand 1 -pady 8

    set logText [text .right.logbox.txt -height 14 -wrap word]
    ttk::scrollbar .right.logbox.sb -orient vertical -command "$logText yview"
    $logText configure -yscrollcommand ".right.logbox.sb set"

    grid $logText -row 0 -column 0 -sticky nsew
    grid .right.logbox.sb -row 0 -column 1 -sticky ns
    grid rowconfigure .right.logbox 0 -weight 1
    grid columnconfigure .right.logbox 0 -weight 1

    ttk::separator .sep -orient horizontal
    pack .sep -fill x
    set statusLabel [ttk::label .status -text "Stato: pronto" -padding 6]
    pack .status -fill x

    bind $canvas <Button-1>        {wf::canvasClick [%W canvasx %x] [%W canvasy %y]}
    bind $canvas <ButtonPress-1>   {wf::dragStart  [%W canvasx %x] [%W canvasy %y]}
    bind $canvas <B1-Motion>       {wf::dragMove   [%W canvasx %x] [%W canvasy %y]}
    bind $canvas <ButtonRelease-1> {wf::dragEnd}

    wf::configureLogTags
    wf::setMode select
}

# --------------------------------------------------
# Main
# --------------------------------------------------
wf::buildUI
wf::loadRadarPreset
wf::log "Workflow Editor V3 stateful inizializzato" ok
wf::log "Preset radar caricato" ok