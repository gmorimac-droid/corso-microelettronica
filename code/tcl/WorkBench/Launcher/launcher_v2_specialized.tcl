#!/usr/bin/env wish

package require Tk 8.6

namespace eval launcher {
    variable profiles {}
    variable selectedIndex -1
    variable processChan ""
    variable running 0
    variable processPid ""

    variable ui
    variable profilesFile "launcher_profiles_v2.tcl"

    variable profileName ""
    variable profileType "python_script"
    variable profileLauncher ""
    variable profileTarget ""
    variable profileConfig ""
    variable profileInput ""
    variable profileOutputDir ""
    variable profileWorkdir "."
    variable profileExtraArgs ""

    variable statusText "Pronto"
}

proc launcher::log {msg} {
    variable ui
    set ts [clock format [clock seconds] -format "%H:%M:%S"]
    $ui(log) insert end "[$ts] $msg\n"
    $ui(log) see end
}

proc launcher::setStatus {msg} {
    variable ui
    variable statusText
    set statusText $msg
    $ui(status) configure -text "Stato: $msg"
}

proc launcher::defaultProfiles {} {
    return {
        {
            name "Python Radar Analysis"
            type "python_script"
            launcher "python3"
            target "radar_analysis.py"
            config "radar_cfg.json"
            input ""
            output_dir "./out"
            workdir "."
            extra_args "--mode batch"
        }
        {
            name "Matlab Orbit Scenario"
            type "matlab_script"
            launcher "matlab"
            target "run_orbit_scenario.m"
            config ""
            input ""
            output_dir "./out"
            workdir "."
            extra_args ""
        }
        {
            name "Matlab Function Runner"
            type "matlab_function"
            launcher "matlab"
            target "run_case"
            config "scenario.json"
            input ""
            output_dir "./out"
            workdir "."
            extra_args ""
        }
        {
            name "C++ Tracker"
            type "cpp_executable"
            launcher ""
            target "./tracker_app"
            config "tracker.cfg"
            input "tracks.bin"
            output_dir "./out"
            workdir "."
            extra_args "--verbose"
        }
        {
            name "HDL Regression Runner"
            type "hdl_runner"
            launcher "python3"
            target "run_hdl_regression.py"
            config "tb_config.json"
            input ""
            output_dir "./sim_out"
            workdir "."
            extra_args "--suite smoke"
        }
    }
}

proc launcher::loadProfiles {} {
    variable profiles
    variable profilesFile

    if {[file exists $profilesFile]} {
        if {[catch {
            set f [open $profilesFile r]
            set profiles [read $f]
            close $f
        } err]} {
            set profiles [launcher::defaultProfiles]
            launcher::log "Errore caricamento profili: $err"
        }
    } else {
        set profiles [launcher::defaultProfiles]
    }
}

proc launcher::saveProfiles {} {
    variable profiles
    variable profilesFile

    if {[catch {
        set f [open $profilesFile w]
        puts $f $profiles
        close $f
    } err]} {
        tk_messageBox -icon error -title "Errore" -message "Salvataggio fallito:\n$err"
        return
    }
    launcher::log "Profili salvati in $profilesFile"
}

proc launcher::refreshProfileList {} {
    variable ui
    variable profiles

    set tree $ui(tree)
    foreach item [$tree children {}] {
        $tree delete $item
    }

    set i 0
    foreach p $profiles {
        $tree insert {} end -id "p$i" -values [list $i [dict get $p name] [dict get $p type]]
        incr i
    }
}

proc launcher::clearEditor {} {
    variable profileName ""
    variable profileType "python_script"
    variable profileLauncher ""
    variable profileTarget ""
    variable profileConfig ""
    variable profileInput ""
    variable profileOutputDir ""
    variable profileWorkdir "."
    variable profileExtraArgs ""
}

proc launcher::newProfile {} {
    variable profiles
    lappend profiles [dict create \
        name "Nuovo Profilo" \
        type "python_script" \
        launcher "python3" \
        target "" \
        config "" \
        input "" \
        output_dir "./out" \
        workdir "." \
        extra_args ""]
    launcher::refreshProfileList
    launcher::log "Creato nuovo profilo"
}

proc launcher::duplicateProfile {} {
    variable profiles
    variable selectedIndex

    if {$selectedIndex < 0} {
        tk_messageBox -icon warning -title "Attenzione" -message "Seleziona un profilo da duplicare."
        return
    }

    set p [lindex $profiles $selectedIndex]
    dict set p name "[dict get $p name] (copy)"
    lappend profiles $p
    launcher::refreshProfileList
    launcher::log "Profilo duplicato"
}

proc launcher::deleteProfile {} {
    variable profiles
    variable selectedIndex

    if {$selectedIndex < 0} {
        tk_messageBox -icon warning -title "Attenzione" -message "Seleziona un profilo da eliminare."
        return
    }

    set newProfiles {}
    set i 0
    foreach p $profiles {
        if {$i != $selectedIndex} {
            lappend newProfiles $p
        }
        incr i
    }

    set profiles $newProfiles
    set selectedIndex -1
    launcher::clearEditor
    launcher::refreshProfileList
    launcher::updateCommandPreview
    launcher::log "Profilo eliminato"
}

proc launcher::loadProfileIntoEditor {idx} {
    variable profiles
    variable selectedIndex
    variable profileName
    variable profileType
    variable profileLauncher
    variable profileTarget
    variable profileConfig
    variable profileInput
    variable profileOutputDir
    variable profileWorkdir
    variable profileExtraArgs

    if {$idx < 0} { return }

    set selectedIndex $idx
    set p [lindex $profiles $idx]

    set profileName      [dict get $p name]
    set profileType      [dict get $p type]
    set profileLauncher  [dict get $p launcher]
    set profileTarget    [dict get $p target]
    set profileConfig    [dict get $p config]
    set profileInput     [dict get $p input]
    set profileOutputDir [dict get $p output_dir]
    set profileWorkdir   [dict get $p workdir]
    set profileExtraArgs [dict get $p extra_args]
}

proc launcher::saveEditorToProfile {} {
    variable profiles
    variable selectedIndex
    variable profileName
    variable profileType
    variable profileLauncher
    variable profileTarget
    variable profileConfig
    variable profileInput
    variable profileOutputDir
    variable profileWorkdir
    variable profileExtraArgs

    if {$selectedIndex < 0} {
        return
    }

    set p [dict create \
        name       $profileName \
        type       $profileType \
        launcher   $profileLauncher \
        target     $profileTarget \
        config     $profileConfig \
        input      $profileInput \
        output_dir $profileOutputDir \
        workdir    $profileWorkdir \
        extra_args $profileExtraArgs]

    set newProfiles {}
    set i 0
    foreach old $profiles {
        if {$i == $selectedIndex} {
            lappend newProfiles $p
        } else {
            lappend newProfiles $old
        }
        incr i
    }
    set profiles $newProfiles
    launcher::refreshProfileList
}

proc launcher::splitArgs {argString} {
    if {[string trim $argString] eq ""} {
        return {}
    }
    return $argString
}

proc launcher::buildMatlabBatchCommand {target config input outputDir extraArgs type} {
    if {$type eq "matlab_script"} {
        return "run('$target')"
    }

    set params {}
    if {$config ne ""} {
        lappend params "'$config'"
    }
    if {$input ne ""} {
        lappend params "'$input'"
    }
    if {$outputDir ne ""} {
        lappend params "'$outputDir'"
    }
    if {$extraArgs ne ""} {
        lappend params "'$extraArgs'"
    }

    return "${target}([join $params ,])"
}

proc launcher::buildCommand {} {
    variable profileType
    variable profileLauncher
    variable profileTarget
    variable profileConfig
    variable profileInput
    variable profileOutputDir
    variable profileExtraArgs

    set cmd {}

    switch -- $profileType {
        python_script {
            set launcher [expr {$profileLauncher eq "" ? "python3" : $profileLauncher}]
            lappend cmd $launcher
            if {$profileTarget ne ""} {
                lappend cmd $profileTarget
            }
            if {$profileConfig ne ""} {
                lappend cmd --config $profileConfig
            }
            if {$profileInput ne ""} {
                lappend cmd --input $profileInput
            }
            if {$profileOutputDir ne ""} {
                lappend cmd --output $profileOutputDir
            }
            foreach a [launcher::splitArgs $profileExtraArgs] {
                lappend cmd $a
            }
        }

        matlab_script -
        matlab_function {
            set launcher [expr {$profileLauncher eq "" ? "matlab" : $profileLauncher}]
            set batchExpr [launcher::buildMatlabBatchCommand \
                $profileTarget $profileConfig $profileInput $profileOutputDir $profileExtraArgs $profileType]
            lappend cmd $launcher -batch $batchExpr
        }

        cpp_executable {
            if {$profileTarget ne ""} {
                lappend cmd $profileTarget
            }
            if {$profileConfig ne ""} {
                lappend cmd --config $profileConfig
            }
            if {$profileInput ne ""} {
                lappend cmd --input $profileInput
            }
            if {$profileOutputDir ne ""} {
                lappend cmd --output $profileOutputDir
            }
            foreach a [launcher::splitArgs $profileExtraArgs] {
                lappend cmd $a
            }
        }

        hdl_runner {
            set launcher [expr {$profileLauncher eq "" ? "python3" : $profileLauncher}]
            lappend cmd $launcher
            if {$profileTarget ne ""} {
                lappend cmd $profileTarget
            }
            if {$profileConfig ne ""} {
                lappend cmd --config $profileConfig
            }
            if {$profileOutputDir ne ""} {
                lappend cmd --output $profileOutputDir
            }
            foreach a [launcher::splitArgs $profileExtraArgs] {
                lappend cmd $a
            }
        }

        default {
            if {$profileLauncher ne ""} {
                lappend cmd $profileLauncher
            }
            if {$profileTarget ne ""} {
                lappend cmd $profileTarget
            }
            foreach a [launcher::splitArgs $profileExtraArgs] {
                lappend cmd $a
            }
        }
    }

    return $cmd
}

proc launcher::updateCommandPreview {} {
    variable ui
    set cmd [launcher::buildCommand]
    $ui(cmdPreview) configure -state normal
    $ui(cmdPreview) delete 1.0 end
    $ui(cmdPreview) insert end [join $cmd " "]
    $ui(cmdPreview) configure -state disabled
}

proc launcher::startProcess {} {
    variable running
    variable processChan
    variable processPid
    variable profileWorkdir

    if {$running} {
        tk_messageBox -icon warning -title "Attenzione" -message "C'è già un processo in esecuzione."
        return
    }

    launcher::saveEditorToProfile
    set cmd [launcher::buildCommand]

    if {[llength $cmd] == 0} {
        tk_messageBox -icon error -title "Errore" -message "Comando vuoto."
        return
    }

    set originalDir [pwd]
    if {$profileWorkdir ne "" && [file isdirectory $profileWorkdir]} {
        cd $profileWorkdir
    }

    if {[catch {
        set processChan [open "|[list {*}$cmd] 2>@1" r]
        fconfigure $processChan -blocking 0 -buffering line
        fileevent $processChan readable [list launcher::onProcessReadable $processChan]
        set processPid [pid $processChan]
        set running 1
    } err]} {
        cd $originalDir
        tk_messageBox -icon error -title "Errore avvio" -message "Impossibile avviare il processo:\n$err"
        return
    }

    cd $originalDir

    launcher::log "Processo avviato"
    launcher::log "CMD: [join $cmd { }]"
    launcher::setStatus "in esecuzione"
}

proc launcher::onProcessReadable {chan} {
    variable running
    variable processChan
    variable processPid

    if {[eof $chan]} {
        set closeMsg ""
        if {[catch {close $chan} err]} {
            set closeMsg $err
        }
        if {$closeMsg ne ""} {
            launcher::log "Processo terminato: $closeMsg"
        } else {
            launcher::log "Processo terminato correttamente"
        }
        set processChan ""
        set processPid ""
        set running 0
        launcher::setStatus "terminato"
        return
    }

    if {[gets $chan line] >= 0} {
        launcher::log $line
    }
}

proc launcher::stopProcess {} {
    variable running
    variable processChan
    variable processPid

    if {!$running} {
        launcher::setStatus "nessun processo attivo"
        return
    }

    if {$processPid ne ""} {
        catch {exec kill $processPid}
        launcher::log "Segnale di stop inviato al processo PID=$processPid"
    }

    catch {close $processChan}
    set processChan ""
    set processPid ""
    set running 0
    launcher::setStatus "fermato"
}

proc launcher::chooseTarget {} {
    variable profileTarget
    set f [tk_getOpenFile -title "Seleziona script o eseguibile"]
    if {$f ne ""} {
        set profileTarget $f
    }
}

proc launcher::chooseConfig {} {
    variable profileConfig
    set f [tk_getOpenFile -title "Seleziona file di configurazione"]
    if {$f ne ""} {
        set profileConfig $f
    }
}

proc launcher::chooseInput {} {
    variable profileInput
    set f [tk_getOpenFile -title "Seleziona input file"]
    if {$f ne ""} {
        set profileInput $f
    }
}

proc launcher::chooseOutputDir {} {
    variable profileOutputDir
    set d [tk_chooseDirectory -title "Seleziona output directory"]
    if {$d ne ""} {
        set profileOutputDir $d
    }
}

proc launcher::chooseWorkdir {} {
    variable profileWorkdir
    set d [tk_chooseDirectory -title "Seleziona working directory"]
    if {$d ne ""} {
        set profileWorkdir $d
    }
}

proc launcher::applyDefaultsForType {} {
    variable profileType
    variable profileLauncher
    variable profileOutputDir

    switch -- $profileType {
        python_script {
            if {$profileLauncher eq ""} { set profileLauncher "python3" }
            if {$profileOutputDir eq ""} { set profileOutputDir "./out" }
        }
        matlab_script -
        matlab_function {
            if {$profileLauncher eq ""} { set profileLauncher "matlab" }
            if {$profileOutputDir eq ""} { set profileOutputDir "./out" }
        }
        cpp_executable {
            if {$profileOutputDir eq ""} { set profileOutputDir "./out" }
        }
        hdl_runner {
            if {$profileLauncher eq ""} { set profileLauncher "python3" }
            if {$profileOutputDir eq ""} { set profileOutputDir "./sim_out" }
        }
    }
    launcher::updateCommandPreview
}

proc launcher::onTreeSelect {} {
    variable ui
    set sel [$ui(tree) selection]
    if {$sel eq ""} { return }
    set item [lindex $sel 0]
    set idx [$ui(tree) set $item idx]
    launcher::loadProfileIntoEditor $idx
    launcher::updateCommandPreview
}

proc launcher::tracePreview {args} {
    after idle launcher::updateCommandPreview
}

proc launcher::buildUI {} {
    variable ui

    wm title . "Tcl/Tk Technical Launcher V2"
    wm geometry . 1200x760
    wm minsize . 980 620
    ttk::style theme use clam

    ttk::frame .toolbar -padding 6
    pack .toolbar -fill x

    ttk::button .toolbar.new   -text "Nuovo" -command launcher::newProfile
    ttk::button .toolbar.dup   -text "Duplica" -command launcher::duplicateProfile
    ttk::button .toolbar.del   -text "Elimina" -command launcher::deleteProfile
    ttk::button .toolbar.save  -text "Salva profili" -command launcher::saveProfiles
    ttk::button .toolbar.run   -text "Avvia" -command launcher::startProcess
    ttk::button .toolbar.stop  -text "Stop" -command launcher::stopProcess

    pack .toolbar.new .toolbar.dup .toolbar.del .toolbar.save .toolbar.run .toolbar.stop -side left -padx 4

    ttk::panedwindow .pw -orient horizontal
    pack .pw -fill both -expand 1

    ttk::frame .left -padding 6
    ttk::frame .right -padding 6
    .pw add .left -weight 1
    .pw add .right -weight 3

    ttk::labelframe .left.box -text "Profili" -padding 6
    pack .left.box -fill both -expand 1

    set ui(tree) [ttk::treeview .left.box.tree -columns {idx name type} -show headings -selectmode browse]
    $ui(tree) heading idx -text "#"
    $ui(tree) heading name -text "Nome"
    $ui(tree) heading type -text "Tipo"
    $ui(tree) column idx -width 40 -anchor center
    $ui(tree) column name -width 190
    $ui(tree) column type -width 140 -anchor center

    ttk::scrollbar .left.box.sb -orient vertical -command "$ui(tree) yview"
    $ui(tree) configure -yscrollcommand ".left.box.sb set"

    grid $ui(tree) -row 0 -column 0 -sticky nsew
    grid .left.box.sb -row 0 -column 1 -sticky ns
    grid rowconfigure .left.box 0 -weight 1
    grid columnconfigure .left.box 0 -weight 1

    bind $ui(tree) <<TreeviewSelect>> launcher::onTreeSelect

    ttk::labelframe .right.edit -text "Parametri esecuzione" -padding 10
    pack .right.edit -fill x

    grid columnconfigure .right.edit 1 -weight 1

    ttk::label .right.edit.l1 -text "Nome profilo:"
    ttk::entry .right.edit.e1 -textvariable launcher::profileName

    ttk::label .right.edit.l2 -text "Tipo:"
    ttk::combobox .right.edit.c2 -textvariable launcher::profileType \
        -values {python_script matlab_script matlab_function cpp_executable hdl_runner} \
        -state readonly

    ttk::label .right.edit.l3 -text "Launcher:"
    ttk::entry .right.edit.e3 -textvariable launcher::profileLauncher

    ttk::label .right.edit.l4 -text "Target:"
    ttk::entry .right.edit.e4 -textvariable launcher::profileTarget
    ttk::button .right.edit.b4 -text "..." -width 3 -command launcher::chooseTarget

    ttk::label .right.edit.l5 -text "Config:"
    ttk::entry .right.edit.e5 -textvariable launcher::profileConfig
    ttk::button .right.edit.b5 -text "..." -width 3 -command launcher::chooseConfig

    ttk::label .right.edit.l6 -text "Input:"
    ttk::entry .right.edit.e6 -textvariable launcher::profileInput
    ttk::button .right.edit.b6 -text "..." -width 3 -command launcher::chooseInput

    ttk::label .right.edit.l7 -text "Output dir:"
    ttk::entry .right.edit.e7 -textvariable launcher::profileOutputDir
    ttk::button .right.edit.b7 -text "..." -width 3 -command launcher::chooseOutputDir

    ttk::label .right.edit.l8 -text "Working dir:"
    ttk::entry .right.edit.e8 -textvariable launcher::profileWorkdir
    ttk::button .right.edit.b8 -text "..." -width 3 -command launcher::chooseWorkdir

    ttk::label .right.edit.l9 -text "Extra args:"
    ttk::entry .right.edit.e9 -textvariable launcher::profileExtraArgs

    ttk::button .right.edit.apply -text "Applica modifiche" -command {
        launcher::saveEditorToProfile
        launcher::updateCommandPreview
    }

    grid .right.edit.l1 -row 0 -column 0 -sticky w -pady 4
    grid .right.edit.e1 -row 0 -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.edit.l2 -row 1 -column 0 -sticky w -pady 4
    grid .right.edit.c2 -row 1 -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.edit.l3 -row 2 -column 0 -sticky w -pady 4
    grid .right.edit.e3 -row 2 -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.edit.l4 -row 3 -column 0 -sticky w -pady 4
    grid .right.edit.e4 -row 3 -column 1 -sticky ew -pady 4
    grid .right.edit.b4 -row 3 -column 2 -sticky ew -padx 4

    grid .right.edit.l5 -row 4 -column 0 -sticky w -pady 4
    grid .right.edit.e5 -row 4 -column 1 -sticky ew -pady 4
    grid .right.edit.b5 -row 4 -column 2 -sticky ew -padx 4

    grid .right.edit.l6 -row 5 -column 0 -sticky w -pady 4
    grid .right.edit.e6 -row 5 -column 1 -sticky ew -pady 4
    grid .right.edit.b6 -row 5 -column 2 -sticky ew -padx 4

    grid .right.edit.l7 -row 6 -column 0 -sticky w -pady 4
    grid .right.edit.e7 -row 6 -column 1 -sticky ew -pady 4
    grid .right.edit.b7 -row 6 -column 2 -sticky ew -padx 4

    grid .right.edit.l8 -row 7 -column 0 -sticky w -pady 4
    grid .right.edit.e8 -row 7 -column 1 -sticky ew -pady 4
    grid .right.edit.b8 -row 7 -column 2 -sticky ew -padx 4

    grid .right.edit.l9 -row 8 -column 0 -sticky w -pady 4
    grid .right.edit.e9 -row 8 -column 1 -columnspan 2 -sticky ew -pady 4

    grid .right.edit.apply -row 9 -column 0 -columnspan 3 -sticky ew -pady 8

    ttk::labelframe .right.cmd -text "Comando finale" -padding 8
    pack .right.cmd -fill x -pady 8

    set ui(cmdPreview) [text .right.cmd.txt -height 4 -wrap word]
    $ui(cmdPreview) configure -state disabled
    pack $ui(cmdPreview) -fill x -expand 1

    ttk::labelframe .right.logbox -text "Log console" -padding 8
    pack .right.logbox -fill both -expand 1

    set ui(log) [text .right.logbox.txt -wrap none]
    ttk::scrollbar .right.logbox.vsb -orient vertical -command "$ui(log) yview"
    ttk::scrollbar .right.logbox.hsb -orient horizontal -command "$ui(log) xview"
    $ui(log) configure -yscrollcommand ".right.logbox.vsb set" -xscrollcommand ".right.logbox.hsb set"

    grid $ui(log) -row 0 -column 0 -sticky nsew
    grid .right.logbox.vsb -row 0 -column 1 -sticky ns
    grid .right.logbox.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .right.logbox 0 -weight 1
    grid columnconfigure .right.logbox 0 -weight 1

    ttk::separator .sep -orient horizontal
    pack .sep -fill x

    set ui(status) [ttk::label .status -text "Stato: Pronto" -padding 6]
    pack .status -fill x

    bind .right.edit.c2 <<ComboboxSelected>> {
        launcher::applyDefaultsForType
    }

    foreach var {
        launcher::profileName
        launcher::profileType
        launcher::profileLauncher
        launcher::profileTarget
        launcher::profileConfig
        launcher::profileInput
        launcher::profileOutputDir
        launcher::profileWorkdir
        launcher::profileExtraArgs
    } {
        trace add variable $var write launcher::tracePreview
    }
}

launcher::buildUI
launcher::loadProfiles
launcher::refreshProfileList
launcher::setStatus "pronto"
launcher::log "Launcher V2 specializzato inizializzato"
launcher::log "Stack supportato: Python / Matlab / C++ / HDL"