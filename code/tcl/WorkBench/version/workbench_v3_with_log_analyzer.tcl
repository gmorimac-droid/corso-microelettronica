#!/usr/bin/env wish

package require Tk 8.6

namespace eval wb {
    variable currentFile ""
    variable currentDomain "radar"
    variable running 0
    variable processChan ""
    variable processPid ""
    variable runtimeLogFile ""
    variable runtimeLogChan ""

    variable ui
    variable cfg
    array set cfg {}

    variable stateFile ".workbench_state.tcl"

    variable launchProfile "Radar Python Chain"
    variable launchProfiles {
        {
            name "Radar Python Chain"
            domain "radar"
            type "python_script"
            launcher "python3"
            target "radar_chain.py"
            workdir "."
            extra_args "--mode batch"
        }
        {
            name "Satellite Matlab Visibility"
            domain "satellite"
            type "matlab_function"
            launcher "matlab"
            target "run_visibility_case"
            workdir "."
            extra_args ""
        }
        {
            name "Underwater C++ Detector"
            domain "underwater"
            type "cpp_executable"
            launcher ""
            target "./uw_detector"
            workdir "."
            extra_args "--threshold auto"
        }
        {
            name "HDL Regression Runner"
            domain "hdl"
            type "hdl_runner"
            launcher "python3"
            target "run_hdl_regression.py"
            workdir "."
            extra_args "--suite smoke --waves"
        }
    }

    variable launchConfigPath ""
    variable launchCaseName ""
    variable launchInputData ""
    variable launchOutputRoot "./runs"
    variable launchWorkdir "."
    variable launchExtraArgs ""
    variable lastRunOutputDir ""

    # analyzer
    variable analyzerCurrentFile ""
    variable analyzerRawLines {}
    variable analyzerVisibleLines {}
    variable analyzerSearchText ""
    variable analyzerFilterError 1
    variable analyzerFilterWarn 1
    variable analyzerFilterInfo 1
    variable analyzerFilterDebug 1
    variable analyzerOnlyMatching 0
}

# -----------------------------
# Preset config
# -----------------------------
proc wb::presetRadar {} {
    return [dict create \
        domain radar \
        general [dict create case_name "radar_case_01" description "Scenario radar batch base"] \
        scenario [dict create duration_s 120 fs_hz 1000000 target_count 3 environment "nominal"] \
        sensor [dict create fc_hz 9400000000 bandwidth_hz 20000000 tx_power_w 1000 gain_db 32] \
        processing [dict create threshold_mode "cfar" integration_pulses 16 tracker "kalman"] \
        io [dict create input_data "data/iq_capture.bin" output_dir "./runs/radar"] \
        notes [dict create author "" tags "batch,test"]]
}

proc wb::presetSatellite {} {
    return [dict create \
        domain satellite \
        general [dict create case_name "leo_visibility_A" description "Scenario satellite visibility"] \
        scenario [dict create duration_s 3600 step_s 1 orbit_type "LEO" environment "nominal"] \
        sensor [dict create fov_deg 12 altitude_m 550000 gain_db 18 pointing_mode "nadir"] \
        processing [dict create coverage_mode "footprint" export_access_windows 1 estimator "deterministic"] \
        io [dict create input_data "" output_dir "./runs/satellite"] \
        notes [dict create author "" tags "visibility,leo"]]
}

proc wb::presetUnderwater {} {
    return [dict create \
        domain underwater \
        general [dict create case_name "uw_passive_01" description "Scenario underwater passive processing"] \
        scenario [dict create duration_s 300 fs_hz 96000 target_count 2 environment "sea_state_2"] \
        sensor [dict create center_freq_hz 25000 array_elements 16 gain_db 20 platform_speed_ms 3] \
        processing [dict create beamforming "delay_sum" detector "energy" threshold_mode "adaptive"] \
        io [dict create input_data "data/hydrophone_01.dat" output_dir "./runs/underwater"] \
        notes [dict create author "" tags "passive,test"]]
}

proc wb::presetHDL {} {
    return [dict create \
        domain hdl \
        general [dict create case_name "tb_smoke_01" description "HDL smoke regression"] \
        scenario [dict create timescale "1ns/1ps" seed 1234 environment "sim"] \
        sensor [dict create dut_name "top_level_dut" clock_mhz 100 reset_cycles 10 interface_mode "axi_stream"] \
        processing [dict create suite "smoke" waves 1 coverage 0 checker_mode "basic"] \
        io [dict create input_data "" output_dir "./runs/hdl"] \
        notes [dict create author "" tags "hdl,smoke"]]
}

proc wb::loadPreset {domain} {
    variable currentDomain
    set currentDomain $domain
    switch -- $domain {
        radar      { set cfg [wb::presetRadar] }
        satellite  { set cfg [wb::presetSatellite] }
        underwater { set cfg [wb::presetUnderwater] }
        hdl        { set cfg [wb::presetHDL] }
        default    { set cfg [wb::presetRadar] }
    }
    wb::loadConfigToUI $cfg
    wb::logRuntime "OK: preset caricato: $domain"
}

# -----------------------------
# Runtime log
# -----------------------------
proc wb::configureRuntimeLogTags {} {
    variable ui
    $ui(runtimeLog) tag configure error -foreground red
    $ui(runtimeLog) tag configure warn  -foreground darkorange3
    $ui(runtimeLog) tag configure ok    -foreground darkgreen
    $ui(runtimeLog) tag configure info  -foreground black
}

proc wb::runtimeTagForMessage {msg} {
    if {[string match "ERROR:*" $msg]} { return error }
    if {[string match "WARN:*" $msg]}  { return warn }
    if {[string match "OK:*" $msg]}    { return ok }
    return info
}

proc wb::logRuntime {msg} {
    variable ui
    set ts [clock format [clock seconds] -format "%H:%M:%S"]
    set tag [wb::runtimeTagForMessage $msg]
    $ui(runtimeLog) insert end "[$ts] $msg\n" $tag
    $ui(runtimeLog) see end

    variable runtimeLogChan
    if {$runtimeLogChan ne ""} {
        puts $runtimeLogChan "[$ts] $msg"
        flush $runtimeLogChan
    }
}

proc wb::clearRuntimeLog {} {
    variable ui
    $ui(runtimeLog) delete 1.0 end
}

# -----------------------------
# JSON parsing/writing
# -----------------------------
proc wb::jsonEscape {s} {
    set s [string map [list "\\" "\\\\" "\"" "\\\"" "\n" "\\n" "\r" "\\r" "\t" "\\t"] $s]
    return $s
}

proc wb::isNumericLiteral {s} {
    return [string is double -strict $s]
}

proc wb::toJson {value {indent 0}} {
    if {[catch {dict size $value}]} {
        if {[wb::isNumericLiteral $value]} {
            return $value
        }
        if {$value eq "true" || $value eq "false" || $value eq "null"} {
            return $value
        }
        return "\"[wb::jsonEscape $value]\""
    }
    set spaces [string repeat " " $indent]
    set inner [string repeat " " [expr {$indent + 2}]]
    set parts {}
    foreach {k v} $value {
        lappend parts "${inner}\"[wb::jsonEscape $k]\": [wb::toJson $v [expr {$indent + 2}]]"
    }
    return "{\n[join $parts ",\n"]\n${spaces}}"
}

proc wb::jsonSkipWs {text idxVar} {
    upvar 1 $idxVar i
    set n [string length $text]
    while {$i < $n} {
        set ch [string index $text $i]
        if {$ch eq " " || $ch eq "\n" || $ch eq "\r" || $ch eq "\t"} {
            incr i
        } else {
            break
        }
    }
}

proc wb::jsonParseString {text idxVar} {
    upvar 1 $idxVar i
    if {[string index $text $i] ne "\""} {
        error "JSON string attesa alla posizione $i"
    }
    incr i
    set result ""
    set n [string length $text]
    while {$i < $n} {
        set ch [string index $text $i]
        if {$ch eq "\""} {
            incr i
            return $result
        }
        if {$ch eq "\\"} {
            incr i
            set esc [string index $text $i]
            switch -- $esc {
                "\"" { append result "\"" }
                "\\" { append result "\\" }
                "/"  { append result "/" }
                "b"  { append result "\b" }
                "f"  { append result "\f" }
                "n"  { append result "\n" }
                "r"  { append result "\r" }
                "t"  { append result "\t" }
                default { append result $esc }
            }
        } else {
            append result $ch
        }
        incr i
    }
    error "Stringa JSON non chiusa"
}

proc wb::jsonParseNumber {text idxVar} {
    upvar 1 $idxVar i
    set start $i
    set n [string length $text]
    while {$i < $n} {
        set ch [string index $text $i]
        if {[string first $ch "0123456789+-.eE"] >= 0} {
            incr i
        } else {
            break
        }
    }
    return [string range $text $start [expr {$i - 1}]]
}

proc wb::jsonParseLiteral {text idxVar lit value} {
    upvar 1 $idxVar i
    if {[string range $text $i [expr {$i + [string length $lit] - 1}]] ne $lit} {
        error "Literal JSON atteso: $lit"
    }
    incr i [string length $lit]
    return $value
}

proc wb::jsonParseArray {text idxVar} {
    upvar 1 $idxVar i
    set result {}
    incr i
    wb::jsonSkipWs $text i
    if {[string index $text $i] eq "]"} {
        incr i
        return $result
    }
    while 1 {
        wb::jsonSkipWs $text i
        lappend result [wb::jsonParseValue $text i]
        wb::jsonSkipWs $text i
        set ch [string index $text $i]
        if {$ch eq ","} {
            incr i
        } elseif {$ch eq "]"} {
            incr i
            break
        } else {
            error "Separatore array JSON non valido"
        }
    }
    return $result
}

proc wb::jsonParseObject {text idxVar} {
    upvar 1 $idxVar i
    set result [dict create]
    incr i
    wb::jsonSkipWs $text i
    if {[string index $text $i] eq "\}"} {
        incr i
        return $result
    }
    while 1 {
        wb::jsonSkipWs $text i
        set key [wb::jsonParseString $text i]
        wb::jsonSkipWs $text i
        if {[string index $text $i] ne ":"} {
            error "':' atteso"
        }
        incr i
        wb::jsonSkipWs $text i
        dict set result $key [wb::jsonParseValue $text i]
        wb::jsonSkipWs $text i
        set ch [string index $text $i]
        if {$ch eq ","} {
            incr i
        } elseif {$ch eq "\}"} {
            incr i
            break
        } else {
            error "Separatore oggetto JSON non valido"
        }
    }
    return $result
}

proc wb::jsonParseValue {text idxVar} {
    upvar 1 $idxVar i
    wb::jsonSkipWs $text i
    set ch [string index $text $i]
    switch -- $ch {
        "\"" { return [wb::jsonParseString $text i] }
        "\{" { return [wb::jsonParseObject $text i] }
        "\[" { return [wb::jsonParseArray $text i] }
        "t"  { return [wb::jsonParseLiteral $text i true true] }
        "f"  { return [wb::jsonParseLiteral $text i false false] }
        "n"  { return [wb::jsonParseLiteral $text i null ""] }
        default {
            if {[string first $ch "-0123456789"] >= 0} {
                return [wb::jsonParseNumber $text i]
            }
            error "Valore JSON non riconosciuto"
        }
    }
}

proc wb::fromJson {text} {
    set i 0
    set value [wb::jsonParseValue $text i]
    wb::jsonSkipWs $text i
    return $value
}

# -----------------------------
# App state
# -----------------------------
proc wb::saveAppState {} {
    variable stateFile
    variable launchProfile
    catch {
        set f [open $stateFile w]
        puts $f [dict create last_profile $launchProfile]
        close $f
    }
}

proc wb::loadAppState {} {
    variable stateFile
    variable launchProfile
    if {![file exists $stateFile]} { return }
    catch {
        set f [open $stateFile r]
        set state [read $f]
        close $f
        if {[dict exists $state last_profile]} {
            set launchProfile [dict get $state last_profile]
        }
    }
}

# -----------------------------
# Config editor
# -----------------------------
proc wb::setCfgField {name value} {
    variable cfg
    set cfg($name) $value
}

proc wb::getCfgField {name} {
    variable cfg
    if {[info exists cfg($name)]} { return $cfg($name) }
    return ""
}

proc wb::loadConfigToUI {cfgDict} {
    variable currentDomain
    set currentDomain [dict get $cfgDict domain]

    wb::setCfgField general.case_name   [expr {[dict exists $cfgDict general case_name] ? [dict get $cfgDict general case_name] : ""}]
    wb::setCfgField general.description [expr {[dict exists $cfgDict general description] ? [dict get $cfgDict general description] : ""}]
    foreach k {duration_s fs_hz target_count environment step_s orbit_type timescale seed} {
        wb::setCfgField scenario.$k [expr {[dict exists $cfgDict scenario $k] ? [dict get $cfgDict scenario $k] : ""}]
    }
    foreach k {
        fc_hz bandwidth_hz tx_power_w gain_db fov_deg altitude_m pointing_mode
        center_freq_hz array_elements platform_speed_ms dut_name clock_mhz
        reset_cycles interface_mode
    } {
        wb::setCfgField sensor.$k [expr {[dict exists $cfgDict sensor $k] ? [dict get $cfgDict sensor $k] : ""}]
    }
    foreach k {
        threshold_mode integration_pulses tracker coverage_mode
        export_access_windows estimator beamforming detector suite
        waves coverage checker_mode
    } {
        wb::setCfgField processing.$k [expr {[dict exists $cfgDict processing $k] ? [dict get $cfgDict processing $k] : ""}]
    }
    wb::setCfgField io.input_data [expr {[dict exists $cfgDict io input_data] ? [dict get $cfgDict io input_data] : ""}]
    wb::setCfgField io.output_dir [expr {[dict exists $cfgDict io output_dir] ? [dict get $cfgDict io output_dir] : ""}]
    wb::setCfgField notes.author  [expr {[dict exists $cfgDict notes author] ? [dict get $cfgDict notes author] : ""}]
    wb::setCfgField notes.tags    [expr {[dict exists $cfgDict notes tags] ? [dict get $cfgDict notes tags] : ""}]

    wb::rebuildDomainEditor
    .configTab.top.domain set $currentDomain
}

proc wb::collectConfigFromUI {} {
    variable currentDomain
    set cfgDict [dict create domain $currentDomain]
    dict set cfgDict general case_name   [wb::getCfgField general.case_name]
    dict set cfgDict general description [wb::getCfgField general.description]
    dict set cfgDict io input_data       [wb::getCfgField io.input_data]
    dict set cfgDict io output_dir       [wb::getCfgField io.output_dir]
    dict set cfgDict notes author        [wb::getCfgField notes.author]
    dict set cfgDict notes tags          [wb::getCfgField notes.tags]

    switch -- $currentDomain {
        radar {
            foreach k {duration_s fs_hz target_count environment} { dict set cfgDict scenario $k [wb::getCfgField scenario.$k] }
            foreach k {fc_hz bandwidth_hz tx_power_w gain_db}      { dict set cfgDict sensor $k [wb::getCfgField sensor.$k] }
            foreach k {threshold_mode integration_pulses tracker}  { dict set cfgDict processing $k [wb::getCfgField processing.$k] }
        }
        satellite {
            foreach k {duration_s step_s orbit_type environment}         { dict set cfgDict scenario $k [wb::getCfgField scenario.$k] }
            foreach k {fov_deg altitude_m gain_db pointing_mode}         { dict set cfgDict sensor $k [wb::getCfgField sensor.$k] }
            foreach k {coverage_mode export_access_windows estimator}    { dict set cfgDict processing $k [wb::getCfgField processing.$k] }
        }
        underwater {
            foreach k {duration_s fs_hz target_count environment}         { dict set cfgDict scenario $k [wb::getCfgField scenario.$k] }
            foreach k {center_freq_hz array_elements gain_db platform_speed_ms} { dict set cfgDict sensor $k [wb::getCfgField sensor.$k] }
            foreach k {beamforming detector threshold_mode}               { dict set cfgDict processing $k [wb::getCfgField processing.$k] }
        }
        hdl {
            foreach k {timescale seed environment}               { dict set cfgDict scenario $k [wb::getCfgField scenario.$k] }
            foreach k {dut_name clock_mhz reset_cycles interface_mode} { dict set cfgDict sensor $k [wb::getCfgField sensor.$k] }
            foreach k {suite waves coverage checker_mode}       { dict set cfgDict processing $k [wb::getCfgField processing.$k] }
        }
    }
    return $cfgDict
}

proc wb::validateConfig {} {
    set ok 1
    foreach name {general.case_name io.output_dir} {
        if {[string trim [wb::getCfgField $name]] eq ""} {
            wb::logRuntime "ERROR: campo obbligatorio mancante: $name"
            set ok 0
        }
    }
    if {$ok} {
        wb::logRuntime "OK: configurazione valida"
    }
    return $ok
}

proc wb::newConfig {} {
    variable currentFile
    variable currentDomain
    set currentFile ""
    wb::loadPreset $currentDomain
    wm title . "Workbench V3"
}

proc wb::openConfig {} {
    variable currentFile
    set f [tk_getOpenFile -title "Apri configurazione JSON" -filetypes {{"JSON files" {.json}} {"All files" {*}}}]
    if {$f eq ""} { return }
    if {[catch {
        set ch [open $f r]
        set content [read $ch]
        close $ch
        set cfgDict [wb::fromJson $content]
        wb::loadConfigToUI $cfgDict
        set currentFile $f
    } err]} {
        tk_messageBox -icon error -title "Errore apertura" -message "Impossibile aprire il file JSON:\n$err"
        wb::logRuntime "ERROR: apertura config fallita: $err"
        return
    }
    wm title . "Workbench V3 - [file tail $currentFile]"
    wb::logRuntime "OK: config caricata da $currentFile"
}

proc wb::saveConfigAs {} {
    variable currentFile
    set f [tk_getSaveFile -title "Salva configurazione" -defaultextension ".json" -filetypes {{"JSON files" {.json}} {"All files" {*}}}]
    if {$f eq ""} { return }
    set currentFile $f
    wb::saveConfig
}

proc wb::saveConfig {} {
    variable currentFile
    if {$currentFile eq ""} {
        wb::saveConfigAs
        return
    }
    if {![wb::validateConfig]} {
        set ans [tk_messageBox -icon warning -type yesno -title "Validazione" -message "La configurazione contiene errori. Salvare comunque?"]
        if {$ans ne "yes"} { return }
    }
    set cfgDict [wb::collectConfigFromUI]
    set json [wb::toJson $cfgDict]
    if {[catch {
        set ch [open $currentFile w]
        puts $ch $json
        close $ch
    } err]} {
        tk_messageBox -icon error -title "Errore" -message "Salvataggio fallito:\n$err"
        wb::logRuntime "ERROR: salvataggio fallito: $err"
        return
    }
    wm title . "Workbench V3 - [file tail $currentFile]"
    wb::logRuntime "OK: config salvata: $currentFile"
}

# -----------------------------
# Launcher
# -----------------------------
proc wb::profileNames {} {
    variable launchProfiles
    set names {}
    foreach p $launchProfiles { lappend names [dict get $p name] }
    return $names
}

proc wb::findProfileByName {name} {
    variable launchProfiles
    foreach p $launchProfiles {
        if {[dict get $p name] eq $name} { return $p }
    }
    return ""
}

proc wb::autoSelectProfileForDomain {} {
    variable currentDomain
    variable launchProfiles
    variable launchProfile
    foreach p $launchProfiles {
        if {[dict get $p domain] eq $currentDomain} {
            set launchProfile [dict get $p name]
            wb::saveAppState
            return
        }
    }
}

proc wb::useConfigInLauncher {} {
    variable currentFile
    variable launchConfigPath
    variable launchCaseName
    variable launchInputData
    variable launchOutputRoot

    if {$currentFile eq ""} {
        set ans [tk_messageBox -icon question -type yesno -title "Salvare prima" -message "La configurazione non è ancora salvata. Vuoi salvarla adesso?"]
        if {$ans eq "yes"} { wb::saveConfig }
    }
    if {$currentFile eq ""} {
        wb::logRuntime "WARN: uso nel launcher annullato: nessun file config disponibile"
        return
    }

    set launchConfigPath $currentFile
    set launchCaseName   [wb::getCfgField general.case_name]
    set launchInputData  [wb::getCfgField io.input_data]
    set launchOutputRoot [wb::getCfgField io.output_dir]

    wb::autoSelectProfileForDomain
    wb::updateCommandPreview
    .nb select .launcherTab
    wb::logRuntime "OK: config associata al launcher"
}

proc wb::buildRunOutputDir {} {
    variable launchOutputRoot
    variable launchCaseName
    set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
    set caseName [string trim $launchCaseName]
    if {$caseName eq ""} { set caseName "run" }
    return [file join $launchOutputRoot "${caseName}_$ts"]
}

proc wb::buildLaunchCommand {} {
    variable launchProfile
    variable launchConfigPath
    variable launchInputData
    variable launchExtraArgs
    variable launchWorkdir

    set p [wb::findProfileByName $launchProfile]
    if {$p eq ""} { return [list {} ""] }

    set type      [dict get $p type]
    set launcher  [dict get $p launcher]
    set target    [dict get $p target]
    set workdir   [dict get $p workdir]
    set extra     [dict get $p extra_args]
    set outputDir [wb::buildRunOutputDir]

    set launchWorkdir $workdir
    set launchExtraArgs $extra

    set cmd {}
    switch -- $type {
        python_script {
            lappend cmd $launcher $target --config $launchConfigPath
            if {[string trim $launchInputData] ne ""} { lappend cmd --input $launchInputData }
            lappend cmd --output $outputDir
            foreach a $extra { lappend cmd $a }
        }
        cpp_executable {
            lappend cmd $target --config $launchConfigPath
            if {[string trim $launchInputData] ne ""} { lappend cmd --input $launchInputData }
            lappend cmd --output $outputDir
            foreach a $extra { lappend cmd $a }
        }
        hdl_runner {
            lappend cmd $launcher $target --config $launchConfigPath --output $outputDir
            foreach a $extra { lappend cmd $a }
        }
        matlab_function {
            set expr [format "%s('%s')" $target $launchConfigPath]
            lappend cmd $launcher -batch $expr
        }
    }
    return [list $cmd $outputDir]
}

proc wb::updateCommandPreview {} {
    variable ui
    lassign [wb::buildLaunchCommand] cmd outdir
    $ui(cmdPreview) configure -state normal
    $ui(cmdPreview) delete 1.0 end
    $ui(cmdPreview) insert end [join $cmd " "]
    if {$outdir ne ""} {
        $ui(cmdPreview) insert end "\n\nOutput dir: $outdir"
        $ui(cmdPreview) insert end "\nRuntime log: [file join $outdir run.log]"
    }
    $ui(cmdPreview) configure -state disabled
}

proc wb::openRuntimeLogFile {outdir} {
    variable runtimeLogFile
    variable runtimeLogChan
    set runtimeLogFile [file join $outdir run.log]
    if {$runtimeLogChan ne ""} {
        catch {close $runtimeLogChan}
    }
    set runtimeLogChan [open $runtimeLogFile w]
}

proc wb::closeRuntimeLogFile {} {
    variable runtimeLogChan
    if {$runtimeLogChan ne ""} {
        catch {close $runtimeLogChan}
        set runtimeLogChan ""
    }
}

proc wb::startRun {} {
    variable running
    variable processChan
    variable processPid
    variable launchWorkdir
    variable lastRunOutputDir

    if {$running} {
        tk_messageBox -icon warning -title "Attenzione" -message "C'è già un processo in esecuzione."
        return
    }
    if {[string trim $::wb::launchConfigPath] eq ""} {
        tk_messageBox -icon warning -title "Config mancante" -message "Associa prima una config al launcher."
        return
    }

    lassign [wb::buildLaunchCommand] cmd outdir
    set lastRunOutputDir $outdir

    if {[llength $cmd] == 0} {
        tk_messageBox -icon error -title "Errore" -message "Comando vuoto."
        return
    }

    file mkdir $outdir
    wb::openRuntimeLogFile $outdir
    wb::clearRuntimeLog

    set oldDir [pwd]
    if {$launchWorkdir ne "" && [file isdirectory $launchWorkdir]} {
        cd $launchWorkdir
    }

    if {[catch {
        set processChan [open "|[list {*}$cmd] 2>@1" r]
        fconfigure $processChan -blocking 0 -buffering line
        fileevent $processChan readable [list wb::onProcessReadable $processChan]
        set processPid [pid $processChan]
        set running 1
    } err]} {
        cd $oldDir
        wb::closeRuntimeLogFile
        tk_messageBox -icon error -title "Errore avvio" -message "Impossibile avviare il processo:\n$err"
        wb::logRuntime "ERROR: avvio processo fallito: $err"
        return
    }

    cd $oldDir
    wb::logRuntime "OK: processo avviato"
    wb::logRuntime "CMD: [join $cmd { }]"
    wb::logRuntime "Output dir: $outdir"
    .status configure -text "Stato: in esecuzione"
    .nb select .runtimeTab
}

proc wb::onProcessReadable {chan} {
    variable running
    variable processChan
    variable processPid

    if {[eof $chan]} {
        set closeMsg ""
        if {[catch {close $chan} err]} {
            set closeMsg $err
        }
        if {$closeMsg ne ""} {
            wb::logRuntime "WARN: processo terminato: $closeMsg"
        } else {
            wb::logRuntime "OK: processo terminato correttamente"
        }
        set running 0
        set processChan ""
        set processPid ""
        wb::closeRuntimeLogFile
        .status configure -text "Stato: terminato"
        return
    }

    if {[gets $chan line] >= 0} {
        set u [string toupper $line]
        if {[string match "*ERROR*" $u] || [string match "*FATAL*" $u]} {
            wb::logRuntime "ERROR: $line"
        } elseif {[string match "*WARN*" $u] || [string match "*WARNING*" $u]} {
            wb::logRuntime "WARN: $line"
        } elseif {[string match "*INFO*" $u]} {
            wb::logRuntime "OK: $line"
        } else {
            wb::logRuntime $line
        }
    }
}

proc wb::stopRun {} {
    variable running
    variable processChan
    variable processPid

    if {!$running} {
        .status configure -text "Stato: nessun processo attivo"
        return
    }
    if {$processPid ne ""} {
        catch {exec kill $processPid}
        wb::logRuntime "WARN: segnale di stop inviato al PID=$processPid"
    }
    catch {close $processChan}
    set running 0
    set processChan ""
    set processPid ""
    wb::closeRuntimeLogFile
    .status configure -text "Stato: fermato"
}

proc wb::openOutputDir {} {
    variable lastRunOutputDir
    if {[string trim $lastRunOutputDir] eq ""} {
        tk_messageBox -icon info -title "Output" -message "Nessuna cartella output disponibile."
        return
    }
    if {![file exists $lastRunOutputDir]} {
        tk_messageBox -icon warning -title "Output" -message "La cartella output non esiste:\n$lastRunOutputDir"
        return
    }
    if {$::tcl_platform(platform) eq "windows"} {
        catch {exec {*}[auto_execok start] "" $lastRunOutputDir &}
    } elseif {$::tcl_platform(os) eq "Darwin"} {
        catch {exec open $lastRunOutputDir &}
    } else {
        catch {exec xdg-open $lastRunOutputDir &}
    }
    wb::logRuntime "OK: apertura output dir: $lastRunOutputDir"
}

# -----------------------------
# Analyzer
# -----------------------------
proc wb::configureAnalyzerTags {} {
    variable ui
    $ui(anViewer) tag configure error -foreground red
    $ui(anViewer) tag configure warn  -foreground darkorange3
    $ui(anViewer) tag configure info  -foreground darkgreen
    $ui(anViewer) tag configure debug -foreground blue
    $ui(anViewer) tag configure other -foreground black
    $ui(anViewer) tag configure hit   -background yellow
}

proc wb::anClassify {line} {
    set u [string toupper $line]
    if {[string match "*ERROR*" $u] || [string match "*FATAL*" $u]} { return error }
    if {[string match "*WARN*" $u] || [string match "*WARNING*" $u]} { return warn }
    if {[string match "*DEBUG*" $u] || [string match "*TRACE*" $u]} { return debug }
    if {[string match "*INFO*" $u] || [string match "*OK:*" $u]} { return info }
    return other
}

proc wb::anSeverityEnabled {sev} {
    variable analyzerFilterError
    variable analyzerFilterWarn
    variable analyzerFilterInfo
    variable analyzerFilterDebug
    switch -- $sev {
        error { return $analyzerFilterError }
        warn  { return $analyzerFilterWarn }
        info  { return $analyzerFilterInfo }
        debug { return $analyzerFilterDebug }
        other { return 1 }
    }
    return 1
}

proc wb::anOpenFile {} {
    variable analyzerCurrentFile
    variable analyzerRawLines
    set f [tk_getOpenFile -title "Apri file di log" -filetypes {{"Log files" {.log .txt .out}} {"All files" {*}}}]
    if {$f eq ""} { return }
    if {[catch {
        set ch [open $f r]
        set content [read $ch]
        close $ch
    } err]} {
        tk_messageBox -icon error -title "Errore" -message "Impossibile aprire il log:\n$err"
        return
    }
    set analyzerCurrentFile $f
    set analyzerRawLines [split $content "\n"]
    wb::anApplyFilters
    wb::logRuntime "OK: log aperto nell'analyzer: $f"
}

proc wb::anAnalyzeLastLog {} {
    variable lastRunOutputDir
    variable analyzerCurrentFile
    variable analyzerRawLines
    if {[string trim $lastRunOutputDir] eq ""} {
        tk_messageBox -icon info -title "Analyzer" -message "Nessuna run recente disponibile."
        return
    }
    set f [file join $lastRunOutputDir run.log]
    if {![file exists $f]} {
        tk_messageBox -icon warning -title "Analyzer" -message "Log non trovato:\n$f"
        return
    }
    if {[catch {
        set ch [open $f r]
        set content [read $ch]
        close $ch
    } err]} {
        tk_messageBox -icon error -title "Errore" -message "Impossibile leggere il log:\n$err"
        return
    }
    set analyzerCurrentFile $f
    set analyzerRawLines [split $content "\n"]
    wb::anApplyFilters
    .nb select .analyzerTab
    wb::logRuntime "OK: analyzer caricato con ultimo log run"
}

proc wb::anSaveFiltered {} {
    variable analyzerVisibleLines
    set f [tk_getSaveFile -title "Salva log filtrato" -defaultextension ".log" -filetypes {{"Log files" {.log .txt}} {"All files" {*}}}]
    if {$f eq ""} { return }
    catch {
        set ch [open $f w]
        puts -nonewline $ch [join $analyzerVisibleLines "\n"]
        close $ch
    }
}

proc wb::anApplyFilters {} {
    variable analyzerRawLines
    variable analyzerVisibleLines
    variable analyzerSearchText
    variable analyzerOnlyMatching
    variable ui

    set analyzerVisibleLines {}
    foreach line $analyzerRawLines {
        set sev [wb::anClassify $line]
        set sevOk [wb::anSeverityEnabled $sev]
        set txtOk [expr {[string trim $analyzerSearchText] eq "" || [string first [string tolower $analyzerSearchText] [string tolower $line]] >= 0}]
        if {$analyzerOnlyMatching} {
            if {$sevOk && $txtOk} { lappend analyzerVisibleLines $line }
        } else {
            if {$sevOk} { lappend analyzerVisibleLines $line }
        }
    }
    wb::anRender
    wb::anRefreshCritical
    wb::anUpdateStats
}

proc wb::anRender {} {
    variable ui
    variable analyzerVisibleLines
    variable analyzerSearchText

    $ui(anViewer) configure -state normal
    $ui(anViewer) delete 1.0 end

    set lineNo 1
    foreach line $analyzerVisibleLines {
        set sev [wb::anClassify $line]
        $ui(anViewer) insert end $line $sev
        $ui(anViewer) insert end "\n"

        if {[string trim $analyzerSearchText] ne ""} {
            set start "$lineNo.0"
            set end "$lineNo.end"
            set pos [$ui(anViewer) search -nocase $analyzerSearchText $start $end]
            while {$pos ne ""} {
                set posEnd "$pos + [string length $analyzerSearchText] chars"
                $ui(anViewer) tag add hit $pos $posEnd
                set pos [$ui(anViewer) search -nocase $analyzerSearchText $posEnd $end]
            }
        }
        incr lineNo
    }
    $ui(anViewer) configure -state disabled
}

proc wb::anRefreshCritical {} {
    variable ui
    variable analyzerVisibleLines
    $ui(anCritical) delete 0 end
    set lineNo 1
    foreach line $analyzerVisibleLines {
        set sev [wb::anClassify $line]
        if {$sev eq "error" || $sev eq "warn"} {
            set short $line
            if {[string length $short] > 120} {
                set short "[string range $short 0 116]..."
            }
            $ui(anCritical) insert end "$lineNo | $short"
        }
        incr lineNo
    }
}

proc wb::anJumpToCritical {} {
    variable ui
    set sel [$ui(anCritical) curselection]
    if {$sel eq ""} { return }
    set item [$ui(anCritical) get [lindex $sel 0]]
    if {[regexp {^([0-9]+)\s+\|} $item -> lineNo]} {
        $ui(anViewer) see "${lineNo}.0"
        $ui(anViewer) tag remove sel 1.0 end
        $ui(anViewer) tag add sel "${lineNo}.0" "${lineNo}.end"
    }
}

proc wb::anFindNext {} {
    variable ui
    variable analyzerSearchText
    if {[string trim $analyzerSearchText] eq ""} { return }
    set cur [$ui(anViewer) index insert]
    set pos [$ui(anViewer) search -nocase $analyzerSearchText "$cur + 1 chars" end]
    if {$pos eq ""} {
        set pos [$ui(anViewer) search -nocase $analyzerSearchText 1.0 end]
    }
    if {$pos ne ""} {
        set posEnd "$pos + [string length $analyzerSearchText] chars"
        $ui(anViewer) see $pos
        $ui(anViewer) tag remove sel 1.0 end
        $ui(anViewer) tag add sel $pos $posEnd
        $ui(anViewer) mark set insert $pos
    }
}

proc wb::anUpdateStats {} {
    variable analyzerVisibleLines
    set e 0; set w 0; set i 0; set d 0; set o 0
    foreach line $analyzerVisibleLines {
        switch -- [wb::anClassify $line] {
            error { incr e }
            warn  { incr w }
            info  { incr i }
            debug { incr d }
            other { incr o }
        }
    }
    .analyzerTab.stats configure -text "ERROR=$e   WARN=$w   INFO=$i   DEBUG=$d   OTHER=$o"
}

# -----------------------------
# UI helpers
# -----------------------------
proc wb::clearFrame {w} {
    foreach c [winfo children $w] { destroy $c }
}

proc wb::buildEditorSection {parent section rows} {
    ttk::frame $parent.$section -padding 10
    grid columnconfigure $parent.$section 1 -weight 1
    set r 0
    foreach row $rows {
        lassign $row key label
        set full "${section}.${key}"
        ttk::label $parent.$section.l$r -text $label
        ttk::entry $parent.$section.e$r -textvariable wb::cfg($full)
        grid $parent.$section.l$r -row $r -column 0 -sticky w -pady 4 -padx 4
        grid $parent.$section.e$r -row $r -column 1 -sticky ew -pady 4 -padx 4
        incr r
    }
    return $parent.$section
}

proc wb::rebuildDomainEditor {} {
    variable currentDomain
    wb::clearFrame .configTab.editor
    ttk::notebook .configTab.editor.nb
    pack .configTab.editor.nb -fill both -expand 1

    set generalRows {{case_name "Case name"} {description "Description"}}
    set ioRows      {{input_data "Input data"} {output_dir "Output dir"}}
    set notesRows   {{author "Author"} {tags "Tags"}}

    switch -- $currentDomain {
        radar {
            set scenarioRows {{duration_s "Duration [s]"} {fs_hz "Sampling freq [Hz]"} {target_count "Target count"} {environment "Environment"}}
            set sensorRows   {{fc_hz "Carrier freq [Hz]"} {bandwidth_hz "Bandwidth [Hz]"} {tx_power_w "TX power [W]"} {gain_db "Gain [dB]"}}
            set procRows     {{threshold_mode "Threshold mode"} {integration_pulses "Integration pulses"} {tracker "Tracker"}}
        }
        satellite {
            set scenarioRows {{duration_s "Duration [s]"} {step_s "Step [s]"} {orbit_type "Orbit type"} {environment "Environment"}}
            set sensorRows   {{fov_deg "FoV [deg]"} {altitude_m "Altitude [m]"} {gain_db "Gain [dB]"} {pointing_mode "Pointing mode"}}
            set procRows     {{coverage_mode "Coverage mode"} {export_access_windows "Export access windows"} {estimator "Estimator"}}
        }
        underwater {
            set scenarioRows {{duration_s "Duration [s]"} {fs_hz "Sampling freq [Hz]"} {target_count "Target count"} {environment "Environment"}}
            set sensorRows   {{center_freq_hz "Center freq [Hz]"} {array_elements "Array elements"} {gain_db "Gain [dB]"} {platform_speed_ms "Platform speed [m/s]"}}
            set procRows     {{beamforming "Beamforming"} {detector "Detector"} {threshold_mode "Threshold mode"}}
        }
        hdl {
            set scenarioRows {{timescale "Timescale"} {seed "Seed"} {environment "Environment"}}
            set sensorRows   {{dut_name "DUT name"} {clock_mhz "Clock [MHz]"} {reset_cycles "Reset cycles"} {interface_mode "Interface mode"}}
            set procRows     {{suite "Suite"} {waves "Waves"} {coverage "Coverage"} {checker_mode "Checker mode"}}
        }
    }

    foreach item {
        {general General generalRows}
        {scenario Scenario scenarioRows}
        {sensor Sensor sensorRows}
        {processing Processing procRows}
        {io I/O ioRows}
        {notes Notes notesRows}
    } {
        lassign $item sec label varName
        set frame [wb::buildEditorSection .configTab.editor.nb $sec [set $varName]]
        .configTab.editor.nb add $frame -text $label
    }
}

# -----------------------------
# Main UI
# -----------------------------
proc wb::buildUI {} {
    variable ui

    wm title . "Workbench V3"
    wm geometry . 1350x860
    wm minsize . 1080 720
    ttk::style theme use clam

    ttk::frame .toolbar -padding 6
    pack .toolbar -fill x

    ttk::button .toolbar.new    -text "Nuova config" -command wb::newConfig
    ttk::button .toolbar.open   -text "Apri config" -command wb::openConfig
    ttk::button .toolbar.save   -text "Salva config" -command wb::saveConfig
    ttk::button .toolbar.valid  -text "Valida" -command wb::validateConfig
    ttk::button .toolbar.use    -text "Usa nel launcher" -command wb::useConfigInLauncher
    ttk::button .toolbar.run    -text "Avvia run" -command wb::startRun
    ttk::button .toolbar.stop   -text "Stop" -command wb::stopRun
    ttk::button .toolbar.out    -text "Apri output dir" -command wb::openOutputDir
    ttk::button .toolbar.alast  -text "Analizza ultimo log" -command wb::anAnalyzeLastLog

    pack .toolbar.new .toolbar.open .toolbar.save .toolbar.valid \
         .toolbar.use .toolbar.run .toolbar.stop .toolbar.out .toolbar.alast \
         -side left -padx 4

    ttk::notebook .nb
    pack .nb -fill both -expand 1

    ttk::frame .configTab -padding 8
    ttk::frame .launcherTab -padding 8
    ttk::frame .runtimeTab -padding 8
    ttk::frame .analyzerTab -padding 8

    .nb add .configTab -text "Config Editor"
    .nb add .launcherTab -text "Launcher"
    .nb add .runtimeTab -text "Runtime Log"
    .nb add .analyzerTab -text "Log Analyzer"

    # Config
    ttk::frame .configTab.top
    pack .configTab.top -fill x

    ttk::label .configTab.top.domainL -text "Dominio:"
    ttk::combobox .configTab.top.domain -state readonly -values {radar satellite underwater hdl} -textvariable wb::currentDomain
    ttk::button .configTab.top.preset -text "Carica preset" -command {wb::loadPreset $wb::currentDomain}

    pack .configTab.top.domainL -side left -padx 3
    pack .configTab.top.domain -side left -padx 3
    pack .configTab.top.preset -side left -padx 3

    ttk::labelframe .configTab.editor -text "Editor configurazione" -padding 6
    pack .configTab.editor -fill both -expand 1 -pady 8

    bind .configTab.top.domain <<ComboboxSelected>> {wb::loadPreset $wb::currentDomain}

    # Launcher
    ttk::labelframe .launcherTab.box -text "Parametri launcher" -padding 10
    pack .launcherTab.box -fill x
    grid columnconfigure .launcherTab.box 1 -weight 1

    ttk::label .launcherTab.box.l1 -text "Profilo:"
    ttk::combobox .launcherTab.box.c1 -state readonly -values [wb::profileNames] -textvariable wb::launchProfile
    ttk::label .launcherTab.box.l2 -text "Config path:"
    ttk::entry .launcherTab.box.e2 -textvariable wb::launchConfigPath
    ttk::label .launcherTab.box.l3 -text "Case name:"
    ttk::entry .launcherTab.box.e3 -textvariable wb::launchCaseName
    ttk::label .launcherTab.box.l4 -text "Input data:"
    ttk::entry .launcherTab.box.e4 -textvariable wb::launchInputData
    ttk::label .launcherTab.box.l5 -text "Output root:"
    ttk::entry .launcherTab.box.e5 -textvariable wb::launchOutputRoot
    ttk::label .launcherTab.box.l6 -text "Workdir:"
    ttk::entry .launcherTab.box.e6 -textvariable wb::launchWorkdir
    ttk::label .launcherTab.box.l7 -text "Extra args:"
    ttk::entry .launcherTab.box.e7 -textvariable wb::launchExtraArgs

    grid .launcherTab.box.l1 -row 0 -column 0 -sticky w -pady 4
    grid .launcherTab.box.c1 -row 0 -column 1 -sticky ew -pady 4
    grid .launcherTab.box.l2 -row 1 -column 0 -sticky w -pady 4
    grid .launcherTab.box.e2 -row 1 -column 1 -sticky ew -pady 4
    grid .launcherTab.box.l3 -row 2 -column 0 -sticky w -pady 4
    grid .launcherTab.box.e3 -row 2 -column 1 -sticky ew -pady 4
    grid .launcherTab.box.l4 -row 3 -column 0 -sticky w -pady 4
    grid .launcherTab.box.e4 -row 3 -column 1 -sticky ew -pady 4
    grid .launcherTab.box.l5 -row 4 -column 0 -sticky w -pady 4
    grid .launcherTab.box.e5 -row 4 -column 1 -sticky ew -pady 4
    grid .launcherTab.box.l6 -row 5 -column 0 -sticky w -pady 4
    grid .launcherTab.box.e6 -row 5 -column 1 -sticky ew -pady 4
    grid .launcherTab.box.l7 -row 6 -column 0 -sticky w -pady 4
    grid .launcherTab.box.e7 -row 6 -column 1 -sticky ew -pady 4

    ttk::labelframe .launcherTab.cmd -text "Comando finale" -padding 8
    pack .launcherTab.cmd -fill both -expand 1 -pady 8
    set ui(cmdPreview) [text .launcherTab.cmd.txt -height 8 -wrap word]
    $ui(cmdPreview) configure -state disabled
    pack $ui(cmdPreview) -fill both -expand 1

    # Runtime log
    ttk::labelframe .runtimeTab.box -text "Runtime log live" -padding 8
    pack .runtimeTab.box -fill both -expand 1
    set ui(runtimeLog) [text .runtimeTab.box.txt -wrap none]
    ttk::scrollbar .runtimeTab.box.vsb -orient vertical -command "$ui(runtimeLog) yview"
    ttk::scrollbar .runtimeTab.box.hsb -orient horizontal -command "$ui(runtimeLog) xview"
    $ui(runtimeLog) configure -yscrollcommand ".runtimeTab.box.vsb set" -xscrollcommand ".runtimeTab.box.hsb set"
    grid $ui(runtimeLog) -row 0 -column 0 -sticky nsew
    grid .runtimeTab.box.vsb -row 0 -column 1 -sticky ns
    grid .runtimeTab.box.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .runtimeTab.box 0 -weight 1
    grid columnconfigure .runtimeTab.box 0 -weight 1

    # Analyzer
    ttk::frame .analyzerTab.top -padding 4
    pack .analyzerTab.top -fill x

    ttk::button .analyzerTab.top.open  -text "Apri log" -command wb::anOpenFile
    ttk::button .analyzerTab.top.last  -text "Analizza ultimo log" -command wb::anAnalyzeLastLog
    ttk::button .analyzerTab.top.save  -text "Salva filtrato" -command wb::anSaveFiltered
    ttk::label  .analyzerTab.top.searchL -text "Cerca:"
    ttk::entry  .analyzerTab.top.searchE -textvariable wb::analyzerSearchText
    ttk::button .analyzerTab.top.find  -text "Trova" -command wb::anFindNext
    ttk::button .analyzerTab.top.apply -text "Applica filtri" -command wb::anApplyFilters

    pack .analyzerTab.top.open .analyzerTab.top.last .analyzerTab.top.save -side left -padx 4
    pack .analyzerTab.top.apply .analyzerTab.top.find -side right -padx 4
    pack .analyzerTab.top.searchE -side right -padx 4
    pack .analyzerTab.top.searchL -side right -padx 4

    ttk::frame .analyzerTab.filters -padding 4
    pack .analyzerTab.filters -fill x
    ttk::checkbutton .analyzerTab.filters.err  -text "ERROR" -variable wb::analyzerFilterError
    ttk::checkbutton .analyzerTab.filters.warn -text "WARN"  -variable wb::analyzerFilterWarn
    ttk::checkbutton .analyzerTab.filters.info -text "INFO"  -variable wb::analyzerFilterInfo
    ttk::checkbutton .analyzerTab.filters.dbg  -text "DEBUG" -variable wb::analyzerFilterDebug
    ttk::checkbutton .analyzerTab.filters.match -text "Solo matching" -variable wb::analyzerOnlyMatching
    pack .analyzerTab.filters.err .analyzerTab.filters.warn .analyzerTab.filters.info .analyzerTab.filters.dbg .analyzerTab.filters.match -side left -padx 6

    ttk::panedwindow .analyzerTab.pw -orient horizontal
    pack .analyzerTab.pw -fill both -expand 1

    ttk::frame .analyzerTab.left -padding 6
    ttk::frame .analyzerTab.right -padding 6
    .analyzerTab.pw add .analyzerTab.left -weight 1
    .analyzerTab.pw add .analyzerTab.right -weight 4

    ttk::labelframe .analyzerTab.left.box -text "Eventi critici" -padding 6
    pack .analyzerTab.left.box -fill both -expand 1
    set ui(anCritical) [listbox .analyzerTab.left.box.lb -exportselection 0]
    ttk::scrollbar .analyzerTab.left.box.sb -orient vertical -command "$ui(anCritical) yview"
    $ui(anCritical) configure -yscrollcommand ".analyzerTab.left.box.sb set"
    grid $ui(anCritical) -row 0 -column 0 -sticky nsew
    grid .analyzerTab.left.box.sb -row 0 -column 1 -sticky ns
    grid rowconfigure .analyzerTab.left.box 0 -weight 1
    grid columnconfigure .analyzerTab.left.box 0 -weight 1

    ttk::labelframe .analyzerTab.right.box -text "Viewer log" -padding 6
    pack .analyzerTab.right.box -fill both -expand 1
    set ui(anViewer) [text .analyzerTab.right.box.txt -wrap none]
    ttk::scrollbar .analyzerTab.right.box.vsb -orient vertical -command "$ui(anViewer) yview"
    ttk::scrollbar .analyzerTab.right.box.hsb -orient horizontal -command "$ui(anViewer) xview"
    $ui(anViewer) configure -yscrollcommand ".analyzerTab.right.box.vsb set" -xscrollcommand ".analyzerTab.right.box.hsb set" -state disabled
    grid $ui(anViewer) -row 0 -column 0 -sticky nsew
    grid .analyzerTab.right.box.vsb -row 0 -column 1 -sticky ns
    grid .analyzerTab.right.box.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .analyzerTab.right.box 0 -weight 1
    grid columnconfigure .analyzerTab.right.box 0 -weight 1

    ttk::label .analyzerTab.stats -text "ERROR=0   WARN=0   INFO=0   DEBUG=0   OTHER=0" -padding 6
    pack .analyzerTab.stats -fill x

    bind $ui(anCritical) <<ListboxSelect>> wb::anJumpToCritical
    bind .analyzerTab.top.searchE <Return> {wb::anApplyFilters}
    bind .launcherTab.box.c1 <<ComboboxSelected>> {wb::saveAppState; wb::updateCommandPreview}

    ttk::separator .sep -orient horizontal
    pack .sep -fill x
    ttk::label .status -text "Stato: pronto" -padding 6
    pack .status -fill x

    foreach var {
        wb::launchProfile
        wb::launchConfigPath
        wb::launchCaseName
        wb::launchInputData
        wb::launchOutputRoot
    } {
        trace add variable $var write wb::tracePreview
    }
}

proc wb::tracePreview {args} {
    after idle wb::updateCommandPreview
}

# -----------------------------
# Main
# -----------------------------
wb::buildUI
wb::configureRuntimeLogTags
wb::configureAnalyzerTags
wb::loadAppState
wb::loadPreset radar
if {[wb::findProfileByName $wb::launchProfile] eq ""} {
    wb::autoSelectProfileForDomain
}
wb::updateCommandPreview
wb::logRuntime "OK: Workbench V3 inizializzato"
wb::logRuntime "OK: integrazione Log Analyzer attiva"